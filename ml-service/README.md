# collabro summarizer service

Serves the multi-task flan-t5 summarization model (see
`../../fine_tune/t5_summarizer_finetune.ipynb`) over HTTP for the Node backend's `summaries`
module. One model handles two tasks, selected per request by a `task` field:

- `"dialogue"` — study session chat recaps (used by `sessions.service.ts`)
- `"notes"` — uploaded notes / text / OCR / video transcript summaries (used by `notes.service.ts`)

## Run

`MODEL_PATH` can point at either a local checkpoint directory or a Hugging Face Hub repo id.
Defaults to base `google/flan-t5-base` if unset (untrained base model — fine for a smoke test,
but won't follow the `"summarize dialogue: "` / `"summarize notes: "` task prefixes properly
until you point it at the fine-tuned checkpoint below).

### Option A: local checkpoint (from the notebook's `trainer.save_model()` output)

Download the `final/` folder produced by the notebook (e.g. from
`/content/drive/MyDrive/t5-collabro-summarizer/final` if you mounted Drive) into
`ml-service/model/` — it's gitignored, so it never gets committed. It should contain
`config.json`, `model.safetensors` (or `pytorch_model.bin`), `spiece.model`,
`tokenizer_config.json`, and `special_tokens_map.json`.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export MODEL_PATH=./model

uvicorn main:app --port 8000
```

### Option B: Hugging Face Hub (private repo)

If you ran the notebook's "Push to Hugging Face Hub" cell instead, create a read-access
token at https://huggingface.co/settings/tokens to pull it.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export MODEL_PATH=<your-hf-username>/t5-collabro-summarizer
export HF_TOKEN=<your-hf-read-token>

uvicorn main:app --port 8000
```

Or, instead of exporting vars each time, drop a `.env` file in this directory (gitignored,
loaded automatically via `python-dotenv`):

```
MODEL_PATH=<your-hf-username>/t5-collabro-summarizer
HF_TOKEN=<your-hf-read-token>
```

The backend talks to this over `SUMMARIZER_URL` (see `backend/.env`), default
`http://localhost:8000`.

## Transcription (Whisper)

Video-call recordings get transcribed with [faster-whisper](https://github.com/SYSTRAN/faster-whisper)
(a CTranslate2 reimplementation of OpenAI's open-source Whisper — self-hosted, no API
cost). `WHISPER_MODEL` picks the model size (`tiny`, `base`, `small`, `medium`, `large-v3`,
...), defaults to `base` — a reasonable CPU speed/accuracy tradeoff. Runs on the same
`device` (CPU/CUDA) the summarizer auto-detects; `compute_type` is `int8` on CPU,
`float16` on GPU.

```
WHISPER_MODEL=base
```

## API

- `GET /health` -> `{"status": "ok"}`
- `POST /summarize` `{"text": "...", "task": "dialogue" | "notes"}` -> `{"summary": "..."}`
  - `task` defaults to `"dialogue"` if omitted, but the backend always sends it explicitly.
- `POST /transcribe` multipart file upload (field name `file`, any audio file
  faster-whisper/ffmpeg can decode — e.g. the `.mp4`-muxed audio `flutter_webrtc`'s
  `MediaRecorder` produces) -> `{"segments": [{"start": 0.0, "end": 2.4, "text": "..."}],
  "language": "en"}`
