# silero_vad_runner.py

import sys
import torch
import pandas as pd
from pathlib import Path

if len(sys.argv) < 3:
    print("Usage: python silero_vad_runner.py audio.wav output_dir")
    sys.exit(1)

audio_path = sys.argv[1]
outdir = Path(sys.argv[2])
outdir.mkdir(parents=True, exist_ok=True)
basename = Path(audio_path).stem
csv_path = outdir / f"{basename}_silero_segments.csv"

# Cargar modelo desde torch.hub
model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad', model='silero_vad', trust_repo=True)

(get_speech_timestamps, _, read_audio, _, _) = utils

# Leer audio (¡debe estar a 16kHz mono!)
wav = read_audio(audio_path, sampling_rate=16000)

# Detectar voz
speech_timestamps = get_speech_timestamps(wav, model, sampling_rate=16000)

# Convertir a segundos
segments = [{"start": round(t["start"] / 16000, 3), "end": round(t["end"] / 16000, 3)} for t in speech_timestamps]
df = pd.DataFrame(segments)
df.to_csv(csv_path, index=False)
print(f"✅ Saved segments to {csv_path}")

