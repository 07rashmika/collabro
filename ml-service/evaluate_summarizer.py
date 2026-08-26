"""
Evaluation script for the Collabro fine-tuned flan-t5 summarizer.

Paste this into a cell (or run as a script) in the SAME Kaggle notebook/session where
your fine-tuned `model` and `tokenizer` were produced (notebooka7e2a42073.ipynb) — it
reuses the exact generation config `ml-service/main.py` uses in production, so the numbers
you get here match what the deployed service would actually produce, not a
differently-tuned decode.

If you're resuming after a disconnect, run the "Resume from the Hub" cell first (see
notebook's "Resuming after a disconnect?" section) so `HF_TOKEN` is logged in and the
private Hub repo is reachable — this script reloads the model itself, it does not depend
on the notebook's in-memory `model`/`tokenizer` objects.

What it does, mirroring the notebook's own per-task held-out eval (cell 23) plus the
Collabro-specific human-rubric addition:
  1. Loads the fine-tuned checkpoint (from the Hub, `07rashmika/t5-collabro-summarizer`)
     AND the untrained base model `google/flan-t5-base` (for comparison).
  2. Generates summaries for three held-out test splits, matching what each task was
     actually fine-tuned on: SAMSum + DialogSum for "dialogue", BookSum for "notes".
  3. Computes ROUGE-1/2/L and BERTScore for each dataset x model combination.
  4. Samples N examples per dataset into a CSV for manual/human rubric scoring — automatic
     metrics alone don't catch hallucination, so this is what backs a "Quality of AI
     Generated Summaries" section that isn't just a ROUGE table.

Install once per Kaggle session (the "Resume from the Hub" cell installs everything else,
but not bert_score):
    !pip install -q bert_score

Usage: edit the CONFIG block if needed, then run all cells / `python evaluate_summarizer.py`.
"""

import csv
import random

import evaluate
import torch
from datasets import load_dataset
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

# ── CONFIG ───────────────────────────────────────────────────────────────────
# HF Hub repo the notebook pushes to (cell 27) — works directly after "Resume from the Hub".
# If you're running this in the same session right after `trainer.save_model(final_dir)`
# (cell 25) and haven't pushed yet, point this at that local dir instead, e.g. "./final".
FINE_TUNED_MODEL_PATH = "07rashmika/t5-collabro-summarizer"
BASE_MODEL_PATH = "google/flan-t5-base"  # untrained baseline, for comparison
N_TEST_EXAMPLES = 100  # how many test examples to score per dataset (SAMSum's test split has 819)
N_HUMAN_EVAL_SAMPLES = 15  # how many to dump to CSV for manual scoring
RANDOM_SEED = 42

# Must match ml-service/main.py exactly — this evaluation is only meaningful if it
# reflects the same decoding the deployed service actually uses.
TASK_PREFIXES = {"dialogue": "summarize dialogue: ", "notes": "summarize notes: "}
MAX_INPUT_LENGTH = 512
MAX_TARGET_LENGTH = 128
NUM_BEAMS = 4
GENERATE_KWARGS = dict(
    max_length=MAX_TARGET_LENGTH,
    num_beams=NUM_BEAMS,
    repetition_penalty=1.3,
    no_repeat_ngram_size=3,
)

device = "cuda" if torch.cuda.is_available() else "cpu"
random.seed(RANDOM_SEED)


def load_samsum_test_set():
    """SAMSum's own held-out test split — never seen during fine-tuning."""
    ds = load_dataset("knkarthick/samsum", split="test")
    ds = ds.select(range(min(N_TEST_EXAMPLES, len(ds))))
    return [{"text": ex["dialogue"], "reference": ex["summary"]} for ex in ds]


def load_dialogsum_test_set():
    """DialogSum's held-out test split — the other dataset "dialogue" was fine-tuned on."""
    ds = load_dataset("knkarthick/dialogsum", split="test")
    ds = ds.select(range(min(N_TEST_EXAMPLES, len(ds))))
    return [{"text": ex["dialogue"], "reference": ex["summary"]} for ex in ds]


def load_booksum_test_set():
    """
    BookSum's held-out test split — what the "notes" task was actually fine-tuned on
    (notebook cell 10: chapter -> summary_text). Some rows have empty chapter/summary
    text (a known BookSum quirk), so those are filtered out before sampling.
    """
    ds = load_dataset("kmfoda/booksum", split="test")
    ds = ds.filter(lambda ex: ex["chapter"] and ex["summary_text"])
    ds = ds.select(range(min(N_TEST_EXAMPLES, len(ds))))
    return [{"text": ex["chapter"], "reference": ex["summary_text"]} for ex in ds]


def load_model(path):
    tokenizer = AutoTokenizer.from_pretrained(path)
    model = AutoModelForSeq2SeqLM.from_pretrained(path).to(device)
    model.eval()
    return model, tokenizer


@torch.no_grad()
def generate(model, tokenizer, task, text):
    inputs = tokenizer(
        TASK_PREFIXES[task] + text,
        return_tensors="pt",
        truncation=True,
        max_length=MAX_INPUT_LENGTH,
    ).to(device)
    output_ids = model.generate(**inputs, **GENERATE_KWARGS)
    return tokenizer.decode(output_ids[0], skip_special_tokens=True)


def run_task(label, task_key, examples, fine_tuned, base):
    """
    label: display name / CSV filename suffix, e.g. "dialogue_samsum".
    task_key: which TASK_PREFIXES entry to use for generation, e.g. "dialogue" or "notes".
    """
    ft_model, ft_tok = fine_tuned
    base_model, base_tok = base

    references, ft_predictions, base_predictions = [], [], []
    for ex in examples:
        references.append(ex["reference"])
        ft_predictions.append(generate(ft_model, ft_tok, task_key, ex["text"]))
        base_predictions.append(generate(base_model, base_tok, task_key, ex["text"]))

    rouge = evaluate.load("rouge")
    bertscore = evaluate.load("bertscore")

    results = {}
    for model_label, preds in [("fine-tuned", ft_predictions), ("base (untrained)", base_predictions)]:
        rouge_scores = rouge.compute(predictions=preds, references=references)
        bert_scores = bertscore.compute(predictions=preds, references=references, lang="en")
        results[model_label] = {
            "rouge1": rouge_scores["rouge1"],
            "rouge2": rouge_scores["rouge2"],
            "rougeL": rouge_scores["rougeL"],
            "bertscore_f1": sum(bert_scores["f1"]) / len(bert_scores["f1"]),
        }

    print(f"\n=== {label} ({len(examples)} test examples) ===")
    print(f"{'model':<20}{'ROUGE-1':>10}{'ROUGE-2':>10}{'ROUGE-L':>10}{'BERTScore-F1':>15}")
    for model_label, m in results.items():
        print(
            f"{model_label:<20}{m['rouge1']:>10.3f}{m['rouge2']:>10.3f}"
            f"{m['rougeL']:>10.3f}{m['bertscore_f1']:>15.3f}"
        )

    # Human-eval CSV: source text, reference, and both models' summaries side by side,
    # with blank columns for a rubric — fill these in by hand for a small qualitative
    # sample. 1-5 scale: does the summary invent anything not in the source
    # (faithfulness), does it capture the key points (coverage), does it read naturally
    # (fluency).
    sample_idx = random.sample(range(len(examples)), min(N_HUMAN_EVAL_SAMPLES, len(examples)))
    out_path = f"human_eval_{label}.csv"
    with open(out_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "source_text", "reference_summary", "fine_tuned_summary", "base_model_summary",
            "faithfulness_1to5", "coverage_1to5", "fluency_1to5", "notes",
        ])
        for i in sample_idx:
            writer.writerow([
                examples[i]["text"], references[i], ft_predictions[i], base_predictions[i],
                "", "", "", "",
            ])
    print(f"Wrote {len(sample_idx)} examples to {out_path} for manual rubric scoring.")

    return results


def main():
    print(f"Device: {device}")
    print("Loading fine-tuned model...")
    fine_tuned = load_model(FINE_TUNED_MODEL_PATH)
    print("Loading base (untrained) model for comparison...")
    base = load_model(BASE_MODEL_PATH)

    # Mirrors the notebook's own per-dataset held-out eval (cell 23): dialogue was
    # fine-tuned on SAMSum + DialogSum pooled, notes on BookSum alone.
    run_task("dialogue_samsum", "dialogue", load_samsum_test_set(), fine_tuned, base)
    run_task("dialogue_dialogsum", "dialogue", load_dialogsum_test_set(), fine_tuned, base)
    run_task("notes_booksum", "notes", load_booksum_test_set(), fine_tuned, base)


if __name__ == "__main__":
    main()
