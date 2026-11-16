"""Validate the full synthetic video run and record its input/model provenance."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import wave

import numpy as np
import pyarrow.parquet as pq
import torch

# Run from the repository root, exactly as CI does.
root = Path('.')
fixture = root/'tests/fixtures/synthetic_en.wav'
manifest = json.loads(fixture.with_suffix('.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest() == manifest['sha256'], 'Fixture digest mismatch'
with wave.open(str(fixture), 'rb') as f:
    assert (f.getframerate(), f.getnchannels(), f.getsampwidth()) == (16000, 1, 2)
    assert f.getnframes()/f.getframerate() == manifest['duration_s']
video = root/'resultados/synthetic_en.mp4'
result = root/'resultados/synthetic_en/synthetic_en_prosody.parquet'
assert video.is_file(), 'Missing resultados/synthetic_en.mp4: run the FFmpeg generation step first'
assert result.is_file(), 'Missing synthetic Parquet: run PAROLE successfully before validation'
df = pq.read_table(result).to_pandas()
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'frame=pts_time', '-of', 'json', str(video)]))
timestamps = np.array([float(frame['pts_time']) for frame in probe['frames']])
assert len(df) == len(timestamps) > 0, 'Frame count changed'
np.testing.assert_allclose(df.frame_timestamp, timestamps, atol=1e-6)
assert np.array_equal(df.frame_id, np.arange(len(df))), 'Frame IDs changed'
assert df.vad.notna().all(), 'Silero did not produce complete VAD'
assert df.pitch.notna().any() and np.isfinite(df.pitch.dropna()).all(), 'Invalid tracked pitch'
assert np.array_equal(df.voice_present, df.pitch.notna()), 'Voice-presence mask changed'
checks = {}
for name, start, end, expected in [('tone220', .8, 1.2, 220.), ('tone440', 1.9, 2.3, 440.)]:
    pitch = df.loc[df.frame_timestamp.between(start,end), 'pitch'].to_numpy()
    assert len(pitch)>0 and np.all(np.abs(pitch-expected)<5), f'{name}: pitch not within 5 Hz'
    checks[name+'_median_hz'] = float(np.median(pitch))
chirp = df.loc[df.frame_timestamp.between(2.95,3.85)].dropna(subset=['pitch'])
expected = 180 + (chirp.frame_timestamp.to_numpy()-2.8)*150
assert len(chirp)>0 and np.median(np.abs(chirp.pitch.to_numpy()-expected))<8, 'Chirp tracking changed'
checks['chirp_median_absolute_error_hz'] = float(np.median(np.abs(chirp.pitch.to_numpy()-expected)))
speech = manifest['timeline'][-2]
speech_vad = df.loc[df.frame_timestamp.between(speech['start_s']+.3, speech['end_s']-.3), 'vad']
assert len(speech_vad)>0 and speech_vad.mean()>.2, 'Synthetic speech not detected'
for start,end in [(.1,.4),(speech['end_s']+.4,manifest['duration_s']-.1)]:
    silence_vad=df.loc[df.frame_timestamp.between(start,end),'vad']
    assert len(silence_vad)>0 and silence_vad.mean()<.1, 'Voice detected in exterior silence'
checks['speech_vad_fraction'] = float(speech_vad.mean())
models = list(Path(torch.hub.get_dir()).glob('snakers4_silero-vad_*/src/silero_vad/data/silero_vad.jit'))
assert len(models)==1, 'Cannot unambiguously identify cached Silero model'
report = dict(fixture_sha256=manifest['sha256'], video_sha256=hashlib.sha256(video.read_bytes()).hexdigest(), model_sha256=hashlib.sha256(models[0].read_bytes()).hexdigest(),
    git_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
    working_tree_dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True).strip()),
    praat=subprocess.check_output([str(root/'env/praat/praat'),'--version'],text=True).strip(),
    ffmpeg=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],
    torch=torch.__version__, frame_count=len(df), checks=checks,
    note='Synthetic smoke test, not accuracy validation on human speech. Exactly one matching Silero JIT file was found for hashing.')
(root/'resultados/synthetic_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))

provenance = json.loads(result.with_name(result.name + '.provenance.json').read_text())
assert provenance['status'] == 'complete'
assert provenance['praat_version'] == report['praat']
assert provenance['parole_commit'] == report['git_commit']
assert provenance['output_sha256'] == hashlib.sha256(result.read_bytes()).hexdigest()
assert provenance['praat_commands']['To Pitch'] == '0.001, 60, 600'
assert provenance['extraction_script_sha256'] == hashlib.sha256((root/'scripts/extract_prosody.praat').read_bytes()).hexdigest()
