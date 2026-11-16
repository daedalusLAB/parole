"""Regenerate the English CI WAV using mathematical tones and eSpeak NG (no recordings)."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import wave

p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, default=Path('tests/fixtures/synthetic_en.wav'))
args = p.parse_args()
sr = 16000
text = 'This is a synthetic voice for testing Parole. One, two, three.'
output = array.array('h')
timeline = []

def add(label, samples):
    start = len(output) / sr
    output.extend(samples)
    timeline.append(dict(label=label, start_s=start, end_s=len(output)/sr))

def silence(seconds):
    return array.array('h', [0]) * round(seconds * sr)

def tone(seconds, f0, f1=None):
    n = round(seconds * sr)
    ramp = round(.02 * sr)
    f1 = f0 if f1 is None else f1
    return array.array('h', (round(.18*32767*min(1, i/ramp, (n-1-i)/ramp)*
        math.sin(2*math.pi*(f0*i/sr+(f1-f0)*(i/sr)**2/(2*seconds)))) for i in range(n)))

add('Silence', silence(.6))
add('220 Hz tone', tone(.8, 220))
add('Silence', silence(.3))
add('440 Hz tone', tone(.8, 440))
add('Silence', silence(.3))
add('Linear chirp 180-360 Hz', tone(1.2, 180, 360))
add('Silence', silence(.7))
with tempfile.TemporaryDirectory() as tmp:
    source, normalized = Path(tmp)/'speech.wav', Path(tmp)/'speech16.wav'
    subprocess.run(['espeak-ng', '-v', 'en-us', '-s', '145', '-p', '45', '-w', str(source), text], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-ar', str(sr), '-ac', '1', str(normalized)], check=True)
    with wave.open(str(normalized), 'rb') as f:
        speech = array.array('h'); speech.frombytes(f.readframes(f.getnframes()))
    if sys.byteorder != 'little': speech.byteswap()
peak = max(map(abs, speech)) or 1
add('Synthetic English speech', array.array('h', (round(x*.65*32767/peak) for x in speech)))
add('Silence', silence(1))
args.output.parent.mkdir(parents=True, exist_ok=True)
if sys.byteorder != 'little': output.byteswap()
with wave.open(str(args.output), 'wb') as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr); f.writeframes(output.tobytes())
manifest = dict(source='Mathematical tones and standard eSpeak NG en-us voice. No human recording or voice cloning.',
                text=text, voice='en-us', speed=145, pitch=45, sample_rate=sr,
                channels=1, sample_width_bytes=2, duration_s=len(output)/sr,
                sha256=hashlib.sha256(args.output.read_bytes()).hexdigest(), timeline=timeline,
                espeak_version=subprocess.check_output(['espeak-ng','--version'],text=True).splitlines()[0].split('  Data at:')[0],
                ffmpeg_version=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0])
args.output.with_suffix('.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(manifest['sha256'])
