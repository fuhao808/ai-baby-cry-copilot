# Training Baseline

This folder contains a reproducible baseline for baby cry classification using the public [Donate-a-Cry corpus](https://github.com/gveres/donateacry-corpus).

## Why this dataset

- Publicly downloadable from GitHub
- Original filenames encode the app-install UUID, which lets us do group-based train/val/test splitting
- The repository also ships a cleaned WAV subset under `donateacry_corpus_cleaned_and_updated_data/`

## Label mapping

The cleaned corpus contains 5 labels:

- `hungry` -> `Hungry`
- `tired` -> `Sleepy`
- `belly_pain` -> `Pain/Gas`
- `burping` -> `Pain/Gas`
- `discomfort` -> `Fussy`

This aligns the training baseline with the current app taxonomy.

## What the script does

`train_baseline.py` will:

1. Clone the public dataset automatically if missing
2. Build a metadata manifest from the cleaned WAV files
3. Split train/val/test by install UUID
4. Convert each clip into a 128x128 log-mel spectrogram
5. Train a small CNN baseline in PyTorch
6. Save a checkpoint, metrics, and split manifests under `training/outputs/`

## Install

```bash
cd /Users/hf/Documents/Playground/ai-baby-cry-copilot/training
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Notebook Model Bakeoff

There is now a notebook version of the training workflow at:

- `notebooks/baby_cry_model_bakeoff.ipynb`
- `LATEST_MODEL_DIRECTION.md`

This notebook is designed for deeper model selection work. It will:

1. Reuse the already-downloaded Donate-a-Cry corpus when present
2. Keep the same group-based split strategy as `train_baseline.py`
3. Compare several model families before you commit to fine-tuning
4. Let you fine-tune the best candidate after the quick bakeoff

Recommended setup for the notebook:

```bash
cd /Users/hf/Documents/Playground/ai-baby-cry-copilot/training
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-notebook.txt
python -m ipykernel install --user --name baby-cry-training --display-name "Python (baby-cry-training)"
jupyter lab
```

Recommended notebook flow:

1. Run the CNN baseline once as an anchor
2. Run the frozen encoder bakeoff
3. Compare validation macro F1 and top-2 accuracy
4. Fine-tune the strongest candidate

Current recommendation:

- Start fine-tuning with `AST`
- Keep `BEATs` and `WavLM` as the strongest alternatives
- Treat larger checkpoints such as `Wav2Vec2-BERT` or infant-specific transformers as later experiments

## CLI Bakeoff

There is also a script version for quick side-by-side comparison of stronger pretrained encoders:

- `run_audio_model_bakeoff.py`

This script:

1. Reuses the exact same Donate-a-Cry split hygiene as the CNN baseline
2. Extracts frozen embeddings from multiple pretrained audio encoders
3. Fits the same balanced linear probe on top of each encoder
4. Compares `accuracy`, `balanced_accuracy`, `macro_f1`, and `top2_accuracy`
5. Writes a ranked summary to `outputs/bakeoff/latest/summary.json`

Recommended first run:

```bash
python run_audio_model_bakeoff.py --cache-embeddings
```

Smaller smoke test:

```bash
python run_audio_model_bakeoff.py --max-samples 120 --cache-embeddings
```

## CLI Fine-Tuning

After the frozen-encoder bakeoff, use the dedicated fine-tuning script:

- `fine_tune_audio_model.py`

Example smoke run:

```bash
python fine_tune_audio_model.py --model ast --epochs 1 --batch-size 2 --max-samples 40 --skip-save-model
```

Example real run:

```bash
python fine_tune_audio_model.py --model ast --epochs 5 --batch-size 4
```

Notes:

- `--skip-save-model` is useful on low-disk machines when you only want metrics first.
- The script keeps the same group-based split rules as the baseline.
- If a fine-tuned model beats the current CNN on `macro F1` and `balanced accuracy`, that is the candidate to export for backend or mobile deployment.

## Quick smoke test

```bash
python train_baseline.py --epochs 1 --max-samples 120
```

## Full baseline run

```bash
python train_baseline.py --epochs 12 --batch-size 16
```

## Outputs

The script writes:

- `outputs/latest/metrics.json`
- `outputs/latest/model.pt`
- `outputs/latest/label_to_index.json`
- `outputs/latest/train_manifest.csv`
- `outputs/latest/val_manifest.csv`
- `outputs/latest/test_manifest.csv`

## Important limitations

- This is a practical baseline, not the final production model
- User-provided cry labels are noisy by nature
- The corpus is highly imbalanced toward hunger
- The next recommended step after this baseline is a pretrained audio encoder pipeline
- The notebook is the main place to do that comparison cleanly
