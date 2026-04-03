# Latest Model Direction

The current production stack uses a pragmatic baseline:

- public `Donate-a-Cry`
- `7s`, `16kHz`, mono waveform normalization
- `128x128 log-mel` preprocessing for the cry classifier
- a small CNN exported to ONNX for backend inference

That is a good MVP anchor, but it is no longer the model family I would prioritize for the next serious iteration.

## Current recommendation

For baby cry work, I recommend treating the model search in two layers:

1. **Practical transfer-learning bakeoff**
   - `AST`
   - `BEATs`
   - `WavLM`
   - `Wav2Vec2`
   - compare them against the existing CNN baseline using the same group-based split

2. **Infant-specific research direction**
   - if you later want a research-grade model, build toward infant-cry-specific transformers with domain robustness and explicit non-cry gating

## Why these models

### AST

AST is still one of the cleanest first serious upgrades for baby cry classification because it is built for broad audio classification rather than only speech transcription.

- Hugging Face AST docs: <https://huggingface.co/docs/transformers/en/model_doc/audio-spectrogram-transformer>

### WavLM

WavLM is a strong speech self-supervised model and often transfers well to paralinguistic signals and noisy vocal cues.

- Hugging Face WavLM docs: <https://huggingface.co/docs/transformers/en/model_doc/wavlm>

### BEATs

BEATs is attractive because it is a more general audio SSL model, not just a speech representation model. That matters because baby cries are non-linguistic acoustic events.

- BEATs paper: <https://arxiv.org/abs/2212.09058>

### Wav2Vec2

Wav2Vec2 is no longer my default first choice here, but it is still a useful transfer baseline because it is mature, widely supported, and fast to compare.

- Audio classification task guide: <https://huggingface.co/docs/transformers/en/tasks/audio_classification>

## Baby-cry-specific research signal

The strongest recent infant-cry-specific direction I found is a transformer-based, domain-robust setup rather than a plain CNN.

- `DACH-TIC`: Domain-Agnostic Causal-Aware Audio Transformer for Infant Cry Classification
  - arXiv: <https://arxiv.org/abs/2512.16271>
  - key idea: hierarchical transformer + causal attention + domain generalization
  - relevance: this lines up with the real weakness of baby cry models, which is poor robustness across devices, environments, and noisy home recordings

I would treat this as a **research direction**, not an immediate production dependency, because there is not a ready-made public checkpoint we can just drop into the app.

## Recommended next step

Run the practical bakeoff first. If one frozen-encoder family clearly beats the current CNN on `macro F1` and `balanced accuracy`, fine-tune that model next.

My default ranking before running the comparison is:

1. `AST`
2. `BEATs`
3. `WavLM`
4. `Wav2Vec2`
5. current `CNN`
