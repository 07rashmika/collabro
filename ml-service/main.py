import os
from typing import Literal

import torch
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

load_dotenv()

MODEL_PATH = os.environ.get("MODEL_PATH", "google/flan-t5-base")
HF_TOKEN = os.environ.get("HF_TOKEN")  # only needed for a private Hub repo

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

app = FastAPI(title="collabro-summarizer")


class SummarizeRequest(BaseModel):
    text: str
    task: Task = "dialogue"


class SummarizeResponse(BaseModel):
    summary: str


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
        )

    summary = tokenizer.decode(output_ids[0], skip_special_tokens=True)
    return SummarizeResponse(summary=summary)
