#!/usr/bin/env python3
"""Bildirim seslerini üretir: Resources/force_alarm.wav ve Resources/force_praise.wav.

    python3 Scripts/make_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "Resources"


def tone(freq, dur, vol=0.6, harmonics=(1.0, 0.35, 0.15)):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        # yumuşak atak/sönüm
        env = min(1.0, t / 0.01) * max(0.0, 1 - t / dur) ** 1.5
        s = sum(a * math.sin(2 * math.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))
        out.append(vol * env * s / sum(harmonics))
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


def write(name, samples):
    OUT.mkdir(exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


# Israrcı alarm: iki kez yükselen üçlü bip
alarm = []
for _ in range(2):
    for f in (880, 1175, 1568):
        alarm += tone(f, 0.14, vol=0.8) + silence(0.04)
    alarm += silence(0.18)
write("force_alarm.wav", alarm)

# Tebrik: neşeli arpej (Do-Mi-Sol-Do)
praise = []
for f in (523.25, 659.25, 783.99):
    praise += tone(f, 0.12, vol=0.55)
praise += tone(1046.5, 0.45, vol=0.6)
write("force_praise.wav", praise)

print("ok")
