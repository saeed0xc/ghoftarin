"""Replaces the synthetic voice with human takes exported from the app's
voice studio (goftarin-voice.zip). Usage:
  python3 tool/import_voice.py goftarin-voice.zip
Each <dir>/<id>.wav becomes assets/<dir>/<id>.mp3 (light noise reduction,
loudness evened). Lines missing from the zip keep their current audio."""
import json, os, subprocess, sys, tempfile, zipfile

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
z = zipfile.ZipFile(sys.argv[1])
names = [n for n in z.namelist() if n.endswith('.wav') and n.split('/')[0] in ('coach', 'partner')]
with tempfile.TemporaryDirectory() as t:
    for n in names:
        if '..' in n: continue
        src = os.path.join(t, os.path.basename(n))
        open(src, 'wb').write(z.read(n))
        dst = os.path.join(root, 'assets', n[:-4] + '.mp3')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-af',
                        'highpass=f=70,afftdn=nf=-30,adelay=80,loudnorm=I=-18:TP=-2',
                        '-ac', '1', '-ar', '24000', '-b:a', '48k', dst], check=True)
print(len(names), 'lines imported')
