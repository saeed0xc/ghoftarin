"""Generates assets/coach/<id>.mp3 from lib/data/coach_lines.dart with an
offline Persian TTS voice (sherpa-onnx + Piper). Usage:
  python3 tool/make_coach.py <sherpa-onnx dir> <voice dir>"""
import os, re, subprocess, sys, tempfile

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sherpa, voice = sys.argv[1], sys.argv[2]
src = open(os.path.join(root, 'lib/data/coach_lines.dart'), encoding='utf-8').read()
lines = re.findall(r"'([a-z_0-9]+)':\s*'([^']+)'", src)
model = next(f for f in os.listdir(voice) if f.endswith('.onnx'))
out_dir = os.path.join(root, 'assets/coach')
env = dict(os.environ, LD_LIBRARY_PATH=os.path.join(sherpa, 'lib'))
for key, text in lines:
    with tempfile.TemporaryDirectory() as t:
        wav = os.path.join(t, 'a.wav')
        subprocess.run([os.path.join(sherpa, 'bin/sherpa-onnx-offline-tts'),
                        f'--vits-model={os.path.join(voice, model)}',
                        f'--vits-tokens={os.path.join(voice, "tokens.txt")}',
                        f'--vits-data-dir={os.path.join(voice, "espeak-ng-data")}',
                        '--vits-length-scale=1.12',  # a little slower: calm, clear
                        f'--output-filename={wav}', text],
                       check=True, env=env, capture_output=True)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav,
                        '-af', 'adelay=150,loudnorm=I=-18:TP=-2,aresample=22050',
                        '-ac', '1', '-b:a', '48k', os.path.join(out_dir, key + '.mp3')], check=True)
    print(key)
