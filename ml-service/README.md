# ml-service

A small Python/FastAPI service that gives Collabro its two AI features:

- **Summarization**: turns chat transcripts, call transcripts and study notes into short summaries, using a fine-tuned **FLAN-T5** model.
- **Transcription**: turns recorded call audio into timestamped text, using **faster-whisper** (Whisper).

The Node backend is the only client. Browsers never call this service directly.

```
 frontend ──► backend (Node/Express) ──HTTP──► ml-service (FastAPI, :8000)
                 │                                 ├─ FLAN-T5 summarizer  (transformers + torch)
                 │                                 └─ Whisper transcriber (faster-whisper / CTranslate2)
                 └─ stores transcript + summary in Postgres (Prisma)
```

## Files

| File | Purpose |
|---|---|
| `main.py` | The whole service: loads both models at startup and exposes the HTTP endpoints. |
| `evaluate_summarizer.py` | Offline evaluation script, run in Kaggle and not deployed. It compares the fine-tuned model with base `flan-t5-base` using ROUGE and BERTScore, and exports CSVs for human rubric scoring. |
| `requirements.txt` | Runtime dependencies. |
| `.env` | Local config (git-ignored). See [Configuration](#configuration). |
| `model/` | Optional local checkpoint directory (git-ignored). Point `MODEL_PATH` at it to run offline. |

## How it works

### Startup

When `main.py` is imported, it does all the heavy work once, before the server accepts requests:

1. Loads `.env` with `python-dotenv`.
2. Picks a device: `cuda` if a GPU is available, otherwise `cpu`.
3. Loads the summarizer tokenizer and model from `MODEL_PATH` with `AutoModelForSeq2SeqLM`, moves the model to the device, and calls `model.eval()`. `MODEL_PATH` can be a Hugging Face Hub repo (for example the private `07rashmika/t5-collabro-summarizer`, which needs `HF_TOKEN`) or a local directory.
4. Loads the Whisper model named by `WHISPER_MODEL`. It uses `float16` on a GPU and `int8` on a CPU, which is quicker and uses less memory there.

Both models live in memory for the life of the process. Every request reuses them, so the first start is slow (it may download models) and requests after that are much faster.

### `POST /summarize`

Request:

```json
{ "text": "Alice: hi\nBob: let's review chapter 3 ...", "task": "dialogue" }
```

`task` is either `"dialogue"` (the default) or `"notes"`.

Response:

```json
{ "summary": "Alice and Bob agree to review chapter 3 ..." }
```

Steps:

1. Trims the text. If it is empty, returns `400`.
2. Adds a task prefix in front of the text. The model was fine-tuned with these prefixes, so it is one model that handles two tasks:
   - `dialogue` → `"summarize dialogue: "` (trained on SAMSum + DialogSum)
   - `notes` → `"summarize notes: "` (trained on BookSum)
3. Tokenizes the result and **truncates it to 512 tokens** (`MAX_INPUT_LENGTH`). Anything beyond that is ignored, so only the start of a very long transcript is summarized.
4. Generates with beam search: `num_beams=4`, `max_length=128`, `repetition_penalty=1.3`, `no_repeat_ngram_size=3`. The last two settings stop the model from looping on the same phrase. This runs under `torch.no_grad()`.
5. Decodes the tokens back to text and returns it.

> The generation settings are copied in `evaluate_summarizer.py` on purpose. If you change them in one file, change them in the other too, or the evaluation numbers will no longer match what production produces.

### `POST /transcribe`

This endpoint takes a `multipart/form-data` upload with one field, `file`, which holds an audio or video file (`.webm`, `.mp4`, `.wav`, …).

Response:

```json
{
  "language": "en",
  "segments": [
    { "start": 0.0, "end": 3.2, "text": "Okay, let's start." },
    { "start": 3.2, "end": 7.9, "text": "First question is about recursion." }
  ]
}
```

Steps:

1. Writes the upload to a temporary file, keeping its extension so ffmpeg can detect the format. It falls back to `.mp4`.
2. Runs `whisper_model.transcribe()`, which detects the language automatically and splits the audio into timestamped segments.
3. Returns the segments with trimmed text, plus the detected language.
4. Deletes the temporary file, even if transcription fails.

### `GET /health`

Returns `{"status": "ok"}`. The service only starts answering after both models have loaded, so a successful response means it is ready.

## How the backend uses it

The backend reads the base URL from `SUMMARIZER_URL`, which defaults to `http://localhost:8000`. It uses two thin clients: `backend/src/modules/summaries/summarizer.client.ts` and `backend/src/modules/sessions/transcription.client.ts`.

| Feature | Backend code | ml-service calls |
|---|---|---|
| Summarize a note | `notes.service.ts` | `/summarize` with `task: "notes"` |
| Summarize a session's chat | `sessions.service.ts` builds `"Name: message"` lines | `/summarize` with `task: "dialogue"` |
| Call recap from a recording | `sessions.service.ts` → `processRecording` | `/transcribe` once per recorded track, then `/summarize` with `task: "dialogue"` |

Call recap flow in detail:

1. After a session is closed, its creator uploads one audio track per participant, with metadata for each track: a label and a `startedAt` time.
2. The backend sends each track to `/transcribe`.
3. It shifts each segment's timestamps by the gap between that track's start and the earliest track's start, so all tracks share one timeline. Then it merges and sorts every segment by time.
4. It formats the merged segments as a `"Label: text"` transcript and sends it to `/summarize` (`dialogue`).
5. It saves both the `transcript` and the `summary` on the session.

## Configuration

Set these environment variables, or put them in `ml-service/.env`:

| Variable | Default | Meaning |
|---|---|---|
| `MODEL_PATH` | `google/flan-t5-base` | Summarizer checkpoint: a Hub repo ID or a local path such as `./model`. Use the fine-tuned `07rashmika/t5-collabro-summarizer`; the default is the untrained base model. |
| `HF_TOKEN` | *(unset)* | Hugging Face token. Only needed if `MODEL_PATH` is a private Hub repo. |
| `WHISPER_MODEL` | `base` | Whisper size: `tiny`, `base`, `small`, `medium`, `large-v3`, … Larger sizes are more accurate but slower. |

## Running locally

```bash
cd ml-service
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

The first start downloads the models into the Hugging Face cache. If the upload contains video or compressed audio, Whisper needs `ffmpeg` installed.

Quick checks:

```bash
curl localhost:8000/health
curl -X POST localhost:8000/summarize -H 'Content-Type: application/json' \
  -d '{"text":"Alice: Can we meet at 5?\nBob: Sure, library.","task":"dialogue"}'
curl -X POST localhost:8000/transcribe -F file=@call.webm
```

The interactive API docs are at `http://localhost:8000/docs`, which FastAPI generates automatically.

## Evaluating the summarizer

`evaluate_summarizer.py` is meant to run in the Kaggle notebook session used for fine-tuning. It needs `evaluate`, `datasets` and `bert_score`, which are not in `requirements.txt`. The script:

1. Loads the fine-tuned model and base `google/flan-t5-base`.
2. Generates summaries for 100 held-out test examples from each of SAMSum, DialogSum (`dialogue`) and BookSum (`notes`), using the same decoding settings as `main.py`.
3. Prints ROUGE-1/2/L and BERTScore-F1 for each model on each dataset.
4. Writes `human_eval_<dataset>.csv` with 15 samples side by side and blank 1–5 columns for faithfulness, coverage and fluency. Automatic metrics miss hallucinations, which is why these are scored by hand.

## Limitations

- **Input is cut off at 512 tokens.** For a long call, only roughly the first few minutes of transcript are summarized. Summarizing chunks and then combining them would fix this.
- **Requests are handled one at a time.** Both handlers run heavy compute on one shared model and there is no batching or queue, so concurrent requests wait on each other. `/transcribe` is an `async` endpoint, but the Whisper call inside it blocks the event loop.
- **There is no authentication and no upload size limit.** The service expects to sit on a private network behind the backend. Do not expose port 8000 publicly.
- **The whole upload is held in memory** (`await file.read()`) before it is written to disk.
