import os
import tempfile
from typing import Literal

import torch
from dotenv import load_dotenv
from faster_whisper import WhisperModel
from fastapi import FastAPI, HTTPException, UploadFile
from pydantic import BaseModel
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

load_dotenv()

MODEL_PATH = os.environ.get("MODEL_PATH", "google/flan-t5-base")
HF_TOKEN = os.environ.get("HF_TOKEN")  # only needed for a private Hub repo
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "base")

Task = Literal["dialogue", "notes"]
TASK_PREFIXES: dict[Task, str] = {
    "dialogue": "summarize dialogue: ",
    "notes": "summarize notes: ",
}
MAX_INPUT_LENGTH = 512
MAX_TARGET_LENGTH = 128
NUM_BEAMS = 4

device = "cuda" if torch.cuda.is_available() else "cpu"
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, token=HF_TOKEN)
model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_PATH, token=HF_TOKEN).to(device)
model.eval()

# faster-whisper (CTranslate2) has its own device/compute-type handling, separate
# from torch's — int8 on CPU is the fast/low-memory default, float16 on GPU.
whisper_model = WhisperModel(
    WHISPER_MODEL,
    device=device,
    compute_type="float16" if device == "cuda" else "int8",
)

app = FastAPI(title="collabro-summarizer")


class SummarizeRequest(BaseModel):
    text: str
    task: Task = "dialogue"


class SummarizeResponse(BaseModel):
    summary: str


class TranscriptSegment(BaseModel):
    start: float
    end: float
    text: str


class TranscribeResponse(BaseModel):
    segments: list[TranscriptSegment]
    language: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/summarize", response_model=SummarizeResponse)
def summarize(req: SummarizeRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text must not be empty")

    inputs = tokenizer(
        TASK_PREFIXES[req.task] + text,
        return_tensors="pt",
        truncation=True,
        max_length=MAX_INPUT_LENGTH,
    ).to(device)

    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_length=MAX_TARGET_LENGTH,
            num_beams=NUM_BEAMS,
            repetition_penalty=1.3,
            no_repeat_ngram_size=3,
        )

    summary = tokenizer.decode(output_ids[0], skip_special_tokens=True)
    return SummarizeResponse(summary=summary)


@app.post("/transcribe", response_model=TranscribeResponse)
async def transcribe(file: UploadFile):
    suffix = os.path.splitext(file.filename or "")[1] or ".mp4"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp_path = tmp.name
        tmp.write(await file.read())

    try:
        segments, info = whisper_model.transcribe(tmp_path)
        return TranscribeResponse(
            segments=[
                TranscriptSegment(start=s.start, end=s.end, text=s.text.strip())
                for s in segments
            ],
            language=info.language,
        )
    finally:
        os.remove(tmp_path)
