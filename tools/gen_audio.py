"""Genera los sonidos y la música placeholder de TalinortIA por síntesis (sin samples de
terceros: son nuestros, sin problemas de licencia). Uso: python tools/gen_audio.py

Salida: assets/audio/sfx/*.wav y assets/audio/music/*.wav (mono, 22.050 Hz, 16 bits).
Se pueden cambiar por sonidos de verdad cuando los tengamos: mismos nombres de archivo.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
rng = random.Random(1337)


def save(path, samples, gain=0.9):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = gain / peak if peak > gain else 1.0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32000)) for s in samples))


def n(seconds):
    return int(seconds * RATE)


def env(i, total, attack=0.005, release=None):
    t = i / RATE
    length = total / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = 1.0 if release is None else max(0.0, 1.0 - max(0.0, t - (length - release)) / release)
    return a * r


def decay(i, rate):
    return math.exp(-i / RATE * rate)


def tone(freq, seconds, kind="sine", rate=8.0, vol=1.0, slide=0.0):
    out = []
    phase = 0.0
    total = n(seconds)
    for i in range(total):
        f = freq * (1.0 + slide * i / total)
        phase += f / RATE
        p = phase % 1.0
        if kind == "sine":
            v = math.sin(2 * math.pi * p)
        elif kind == "square":
            v = 1.0 if p < 0.5 else -1.0
        elif kind == "saw":
            v = 2 * p - 1
        else:
            v = 1 - 4 * abs(p - 0.5)
        out.append(v * decay(i, rate) * vol * env(i, total, 0.003))
    return out


def noise(seconds, rate=20.0, vol=1.0, lowpass=0.0):
    out = []
    last = 0.0
    total = n(seconds)
    for i in range(total):
        v = rng.uniform(-1, 1)
        if lowpass > 0:
            last = last + (v - last) * (1 - lowpass)
            v = last
        out.append(v * decay(i, rate) * vol * env(i, total, 0.002))
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def add_at(base, track, start, vol=1.0):
    s = n(start)
    if len(base) < s + len(track):
        base.extend([0.0] * (s + len(track) - len(base)))
    for i, v in enumerate(track):
        base[s + i] += v * vol


def sweep_noise(seconds, start_lp, end_lp, vol=1.0, rate=6.0):
    out = []
    last = 0.0
    total = n(seconds)
    for i in range(total):
        lp = start_lp + (end_lp - start_lp) * i / total
        last = last + (rng.uniform(-1, 1) - last) * (1 - lp)
        out.append(last * vol * math.sin(math.pi * i / total) * decay(i, rate))
    return out


# --- Efectos ---
SFX = {
    "hit": lambda: mix(noise(0.08, 45, 0.7, 0.5), tone(110, 0.1, "sine", 30, 0.9, -0.4)),
    "hit_heavy": lambda: mix(noise(0.15, 22, 0.8, 0.7), tone(70, 0.2, "sine", 15, 1.0, -0.5)),
    "crit": lambda: mix(noise(0.08, 45, 0.6, 0.4), tone(120, 0.1, "sine", 30, 0.8, -0.4),
                        tone(1760, 0.18, "triangle", 18, 0.35)),
    "player_hurt": lambda: mix(tone(90, 0.18, "square", 18, 0.35, -0.3), noise(0.12, 25, 0.5, 0.75)),
    "dodge": lambda: sweep_noise(0.22, 0.95, 0.6, 0.8),
    "shot": lambda: mix(noise(0.07, 60, 0.9, 0.2), tone(300, 0.05, "square", 60, 0.3, -0.6)),
    "enemy_death": lambda: mix(tone(220, 0.35, "saw", 7, 0.35, -0.6), noise(0.2, 15, 0.4, 0.8)),
    "coin": lambda: mix(tone(1318, 0.09, "triangle", 25, 0.6), [0.0] * n(0.06) + tone(1975, 0.16, "triangle", 18, 0.6)),
    "chest": lambda: mix(tone(180, 0.35, "saw", 4, 0.25, 0.8), [0.0] * n(0.25) + tone(1046, 0.1, "triangle", 20, 0.5),
                         [0.0] * n(0.33) + tone(1568, 0.25, "triangle", 12, 0.5)),
    "vase": lambda: mix(noise(0.25, 18, 0.9, 0.3), noise(0.1, 40, 0.6, 0.1)),
    "door": lambda: mix(noise(0.6, 4, 0.6, 0.93), tone(55, 0.6, "sine", 3, 0.6)),
    "warning": lambda: tone(660, 0.12, "triangle", 14, 0.5, 0.25),
    "ui_move": lambda: tone(880, 0.04, "square", 60, 0.25),
    "ui_confirm": lambda: mix(tone(784, 0.08, "triangle", 25, 0.5), [0.0] * n(0.06) + tone(1175, 0.14, "triangle", 18, 0.5)),
    "ui_error": lambda: tone(140, 0.2, "square", 8, 0.35),
    "heal": lambda: mix(*[[0.0] * n(0.07 * k) + tone(f, 0.25, "sine", 10, 0.4) for k, f in enumerate([523, 659, 784, 1046])]),
    "ult": lambda: mix(sweep_noise(0.7, 0.98, 0.5, 0.8, 2.0), tone(110, 0.8, "saw", 3, 0.35, 1.0)),
    "roar": lambda: [v * (0.6 + 0.4 * math.sin(i / RATE * 2 * math.pi * 9)) for i, v in
                     enumerate(mix(tone(70, 1.3, "saw", 1.8, 0.8, -0.3), noise(1.3, 2.5, 0.5, 0.85)))],
    "drum": lambda: mix(tone(60, 0.25, "sine", 14, 1.0, -0.3), noise(0.05, 60, 0.3, 0.6)),
    "pickup": lambda: mix(tone(523, 0.08, "triangle", 25, 0.5), [0.0] * n(0.05) + tone(784, 0.08, "triangle", 25, 0.5),
                          [0.0] * n(0.1) + tone(1046, 0.18, "triangle", 14, 0.5)),
}
# Voz inventada tipo balbuceo (GDD, Audio): sílabas cortas a distintas alturas.
for k, f in enumerate([220, 247, 277, 311, 349]):
    SFX["babble_%d" % k] = (lambda f=f: [v * (0.5 + 0.5 * math.sin(i / RATE * 2 * math.pi * 30))
                                          for i, v in enumerate(tone(f, 0.09, "square", 12, 0.35, rng.uniform(-0.2, 0.2)))])


# --- Música (loops) ---

def drum_loop(bpm, bars, pattern, voices, swing=0.0):
    beat = 60.0 / bpm
    length = bars * 4 * beat
    out = [0.0] * n(length)
    steps = bars * 16
    for s in range(steps):
        step_time = s * beat / 4 + (swing * beat / 4 if s % 2 == 1 else 0.0)
        for voice, hits in pattern.items():
            if hits[s % len(hits)] == "x":
                # Torpe a propósito (Talinorthland): un poquito de desfase.
                add_at(out, voices[voice](), step_time + rng.uniform(0.0, 0.012))
    return out[:n(length)]


def melody(bpm, bars, notes, kind="triangle", vol=0.25, rate=6.0):
    beat = 60.0 / bpm
    out = [0.0] * n(bars * 4 * beat)
    for start, freq, dur in notes:
        add_at(out, tone(freq, dur * beat, kind, rate, vol), start * beat)
    return out[:n(bars * 4 * beat)]


def loop_fade(samples):
    # Suaviza la unión del loop.
    fade = n(0.02)
    for i in range(fade):
        samples[i] *= i / fade
        samples[-1 - i] *= i / fade
    return samples


def tom(freq):
    return lambda: tone(freq, 0.25, "sine", 12, 0.9, -0.25)


SHAKER = lambda: noise(0.05, 70, 0.25, 0.1)
KICK = lambda: mix(tone(55, 0.3, "sine", 12, 1.0, -0.4), noise(0.03, 80, 0.2, 0.5))
SNARE = lambda: mix(noise(0.12, 30, 0.6, 0.2), tone(200, 0.08, "triangle", 30, 0.3))
CLAP = lambda: noise(0.08, 35, 0.5, 0.3)


def music():
    tracks = {}
    # Talinorthland: percusión tribal medio torpe, 100 bpm, 8 compases. Capa de combate aparte.
    tali_drums = {"low": "x.......x..x....", "mid": "....x.......x...", "shaker": "..x...x...x...x."}
    voices = {"low": tom(85), "mid": tom(140), "shaker": SHAKER}
    explore = drum_loop(100, 8, tali_drums, voices)
    pent = [220, 247, 294, 330, 392, 440]
    notes = []
    for bar in range(8):
        for beat in [0, 1.5, 3]:
            if rng.random() < 0.7:
                notes.append((bar * 4 + beat, pent[rng.randrange(len(pent))] * 0.5, 0.8))
    explore = mix(explore, melody(100, 8, notes, "triangle", 0.18, 3.0))
    tracks["talinorthland_explore"] = explore
    combat_drums = {"kick": "x...x..xx...x...", "snare": "....x.......x..x", "low": "..x..x....x..x..",
                    "shaker": "xxxxxxxxxxxxxxxx"}
    combat = drum_loop(100, 8, combat_drums, {"kick": KICK, "snare": SNARE, "low": tom(110), "shaker": SHAKER})
    bass = melody(100, 8, [(b * 2, [110, 110, 98, 123][(b // 2) % 4], 1.6) for b in range(16)], "saw", 0.16, 2.0)
    tracks["talinorthland_combat"] = mix(combat, bass)
    # Birig Bamba: el asteroide late como un tambor, con un aire de cantina (120 bpm, swing).
    hub_drums = {"kick": "x...x...x...x...", "clap": "....x.......x...", "shaker": "..x...x...x...x."}
    hub = drum_loop(120, 8, hub_drums, {"kick": KICK, "clap": CLAP, "shaker": SHAKER}, swing=0.3)
    scale = [330, 370, 415, 494, 554, 659]
    cantina = []
    for bar in range(8):
        for step in range(8):
            if rng.random() < 0.55:
                cantina.append((bar * 4 + step * 0.5, scale[rng.randrange(len(scale))], 0.4))
    tracks["birig_bamba"] = mix(hub, melody(120, 8, cantina, "square", 0.08, 9.0))
    # Boss: tambores pesados y un zumbido grave (110 bpm).
    boss_drums = {"kick": "x..x..x.x..x..x.", "snare": "....x.......x...", "low": "x.x.x.x.x.x.x.x."}
    boss = drum_loop(110, 8, boss_drums, {"kick": KICK, "snare": SNARE, "low": tom(70)})
    drone = melody(110, 8, [(b * 4, [55, 52, 49, 58][b % 4], 4.0) for b in range(8)], "saw", 0.2, 0.6)
    tracks["boss"] = mix(boss, drone)
    return tracks


def main():
    for name, make in SFX.items():
        save(os.path.join(ROOT, "sfx", name + ".wav"), make())
    for name, samples in music().items():
        save(os.path.join(ROOT, "music", name + ".wav"), loop_fade(samples), 0.8)
    print("listo:", len(SFX), "efectos y 5 temas")


if __name__ == "__main__":
    main()
