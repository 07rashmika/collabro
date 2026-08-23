"""
Evaluation script for the Collabro fine-tuned flan-t5 summarizer.

Paste this into a cell (or run as a script) in the SAME Kaggle notebook/session where
your fine-tuned `model` and `tokenizer` were produced — it reuses the exact generation
config `ml-service/main.py` uses in production, so the numbers you get here match what
the deployed service would actually produce, not a differently-tuned decode.

What it does:
  1. Loads your fine-tuned checkpoint AND the untrained base model (for comparison).
  2. Generates summaries for the SAMSum test split (dialogue task) with both.
  3. Generates summaries for your notes-task test set with both (edit load_notes_test_set()
     below to point at whatever dataset you actually fine-tuned the notes task on).
  4. Computes ROUGE-1/2/L and BERTScore for each task x model combination.
  5. Samples N examples per task into a CSV for manual/human rubric scoring — automatic
     metrics alone don't catch hallucination, so this is what backs a "Quality of AI
     Generated Summaries" section that isn't just a ROUGE table.

Install once per Kaggle session:
    !pip install -q evaluate rouge_score bert_score

Usage: edit the CONFIG block, then run all cells / `python evaluate_summarizer.py`.
"""

import csv
import random

import evaluate
import torch
from datasets import load_dataset
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

# ── CONFIG ───────────────────────────────────────────────────────────────────
FINE_TUNED_MODEL_PATH = "./final"  # your trainer.save_model() output dir, or HF repo id
BASE_MODEL_PATH = "google/flan-t5-base"  # untrained baseline, for comparison
N_TEST_EXAMPLES = 100  # how many test examples to score per task (SAMSum's test split has 819)
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


def load_dialogue_test_set():
    """SAMSum's own held-out test split — never seen during fine-tuning."""
    ds = load_dataset("samsum", split="test")
    ds = ds.select(range(min(N_TEST_EXAMPLES, len(ds))))
    return [{"text": ex["dialogue"], "reference": ex["summary"]} for ex in ds]


def load_notes_test_set():
    """
    EDIT ME: point this at whatever dataset you fine-tuned the "notes" task on, using
    its held-out test split. Two common shapes:

    Option A — a Hugging Face dataset:
        ds = load_dataset("<hf-dataset-name>", split="test")
        return [{"text": ex["<source-column>"], "reference": ex["<summary-column>"]}
                 for ex in ds.select(range(min(N_TEST_EXAMPLES, len(ds))))]

    Option B — a local CSV with columns "text","summary":
        rows = []
        with open("notes_test.csv") as f:
            for row in csv.DictReader(f):
                rows.append({"text": row["text"], "reference": row["summary"]})
        random.shuffle(rows)
        return rows[:N_TEST_EXAMPLES]
    """
    raise NotImplementedError(
        "Point load_notes_test_set() at your actual notes-task test split before running."
    )


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


def run_task(task_name, examples, fine_tuned, base):
    ft_model, ft_tok = fine_tuned
    base_model, base_tok = base

    references, ft_predictions, base_predictions = [], [], []
    for ex in examples:
        references.append(ex["reference"])
        ft_predictions.append(generate(ft_model, ft_tok, task_name, ex["text"]))
        base_predictions.append(generate(base_model, base_tok, task_name, ex["text"]))

    rouge = evaluate.load("rouge")
    bertscore = evaluate.load("bertscore")

    results = {}
    for label, preds in [("fine-tuned", ft_predictions), ("base (untrained)", base_predictions)]:
        rouge_scores = rouge.compute(predictions=preds, references=references)
        bert_scores = bertscore.compute(predictions=preds, references=references, lang="en")
        results[label] = {
            "rouge1": rouge_scores["rouge1"],
            "rouge2": rouge_scores["rouge2"],
            "rougeL": rouge_scores["rougeL"],
            "bertscore_f1": sum(bert_scores["f1"]) / len(bert_scores["f1"]),
        }

    print(f"\n=== {task_name} ({len(examples)} test examples) ===")
    print(f"{'model':<20}{'ROUGE-1':>10}{'ROUGE-2':>10}{'ROUGE-L':>10}{'BERTScore-F1':>15}")
    for label, m in results.items():
        print(
            f"{label:<20}{m['rouge1']:>10.3f}{m['rouge2']:>10.3f}"
            f"{m['rougeL']:>10.3f}{m['bertscore_f1']:>15.3f}"
        )

    # Human-eval CSV: source text, reference, and both models' summaries side by side,
    # with blank columns for a rubric — fill these in by hand for a small qualitative
    # sample. 1-5 scale: does the summary invent anything not in the source
    # (faithfulness), does it capture the key points (coverage), does it read naturally
    # (fluency).
    sample_idx = random.sample(range(len(examples)), min(N_HUMAN_EVAL_SAMPLES, len(examples)))
    out_path = f"human_eval_{task_name}.csv"
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

    dialogue_examples = load_dialogue_test_set()
    run_task("dialogue", dialogue_examples, fine_tuned, base)

    try:
        notes_examples = load_notes_test_set()
        run_task("notes", notes_examples, fine_tuned, base)
    except NotImplementedError as e:
        print(f"\nSkipped notes-task evaluation: {e}")


if __name__ == "__main__":
    main()
