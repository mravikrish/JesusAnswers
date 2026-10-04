"""Composes the app's background music — our own, so free of any licence — into assets/music/.

Usage:  python tool/build_music.py      (needs numpy, scipy, soundfile)

Two quiet loops to sit under a voice reading Scripture, played softly enough not to
compete with the words:
  pad.mp3      warm strings, no melody — under the words of Jesus (the male voice)
  hymn.mp3     "Amazing Grace" (New Britain, 1829; public domain) on a slow, soft piano —
               under everything else (the female voice)

Each is rendered with its reverb tail folded back onto its start, so it loops without a seam.
(A tanpura drone was auditioned too.)
"""
import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
OUT = 'assets/music'
RNG = np.random.default_rng(7)


def note(name):
    """'D3' → Hz."""
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    return 440.0 * 2 ** ((names[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


def lowpass(x, hz, order=2):
    return sosfilt(butter(order, hz, 'low', fs=SR, output='sos'), x)


def reverb(stereo, seconds=3.5, wet=0.35):
    """A soft hall: convolution with decaying, slightly different noise per ear."""
    n = int(seconds * SR)
    decay = np.exp(-np.linspace(0, 7, n))
    out = []
    for ch in range(2):
        ir = lowpass(RNG.standard_normal(n), 5000) * decay
        ir /= np.sqrt(np.sum(ir ** 2))
        wet_ch = np.zeros(stereo.shape[1] + n)
        conv = fftconvolve(stereo[ch], ir)[: stereo.shape[1] + n]
        wet_ch[: len(conv)] = conv
        out.append(wet_ch)
    tail = np.zeros((2, stereo.shape[1] + n))
    tail[:, : stereo.shape[1]] = stereo * (1 - wet)
    return tail + np.array(out) * wet


def loop(stereo, length):
    """Folds everything past [length] samples back onto the start, for a seamless loop."""
    out = stereo[:, :length].copy()
    rest = stereo[:, length:]
    while rest.shape[1]:
        k = min(length, rest.shape[1])
        out[:, :k] += rest[:, :k]
        rest = rest[:, k:]
    return out


def envelope(n, attack, release):
    env = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    env[:a] = np.linspace(0, 1, a) ** 2
    env[n - r:] *= np.linspace(1, 0, r) ** 2
    return env


def pad():
    chords = [['D3', 'A3', 'D4', 'F#4'], ['B2', 'F#3', 'D4', 'B3'], ['G2', 'D3', 'B3', 'G4'], ['A2', 'E3', 'C#4', 'A3'],
              ['D3', 'A3', 'F#4', 'D4'], ['G2', 'D3', 'G3', 'B3'], ['E2', 'B2', 'G3', 'E4'], ['A2', 'E3', 'A3', 'C#4']]
    beat = 8.0  # seconds per chord
    length = int(len(chords) * beat * SR)
    out = np.zeros((2, length + int(4 * SR)))
    t = np.arange(int((beat + 4) * SR)) / SR
    for i, chord in enumerate(chords):
        start = int(i * beat * SR)
        env = envelope(len(t), 2.5, 4.5)
        for j, name in enumerate(chord):
            f = note(name)
            for ch, detune in enumerate((-0.12, 0.12)):  # a few cents apart per ear: a gentle chorus
                ff = f * 2 ** (detune / 12 + 0.003 * np.sin(2 * np.pi * (0.2 + j * 0.03) * t))
                phase = 2 * np.pi * np.cumsum(ff) / SR
                # A soft "string" tone: odd and even harmonics falling off quickly.
                tone = sum(np.sin(k * phase) / k ** 1.6 for k in range(1, 9))
                out[ch, start:start + len(t)] += lowpass(tone, 1800) * env * 0.12
    return loop(reverb(out, 4.5, 0.45), length)


def hymn():
    # Amazing Grace (New Britain), in D, 3/4. (note, beats).
    melody = [
        ('A3', 1), ('D4', 2), ('F#4', .5), ('D4', .5), ('F#4', 2), ('E4', 1), ('D4', 2), ('B3', 1), ('A3', 2),
        ('A3', 1), ('D4', 2), ('F#4', .5), ('D4', .5), ('F#4', 2), ('E4', 1), ('A4', 5),
        ('F#4', 1), ('A4', 1.5), ('F#4', .5), ('A4', .5), ('F#4', .5), ('D4', 2), ('A3', 1), ('B3', 1.5), ('D4', .5), ('D4', .5), ('B3', .5), ('A3', 2),
        ('A3', 1), ('D4', 2), ('F#4', .5), ('D4', .5), ('F#4', 2), ('E4', 1), ('D4', 5),
    ]
    beat = 60 / 58
    # One chord per bar (3 beats), after the one-beat pickup.
    bars = ['D', 'D', 'G', 'D', 'D', 'D', 'A', 'A', 'D', 'D', 'G', 'D', 'Bm', 'A', 'D', 'D']
    chords = {'D': ['D2', 'A2', 'F#3'], 'G': ['G2', 'D3', 'B3'], 'A': ['A2', 'E3', 'C#4'], 'Bm': ['B2', 'F#3', 'D4']}
    total = sum(d for _, d in melody)
    length = int((total + 3) * beat * SR)
    out = np.zeros((2, length + int(5 * SR)))

    def piano(f, seconds, velocity):
        t = np.arange(int(seconds * SR)) / SR
        tone = np.zeros_like(t)
        for k in range(1, 12):
            fk = f * k * np.sqrt(1 + 0.0002 * k * k)  # a touch of string stiffness
            tone += np.sin(2 * np.pi * fk * t) * np.exp(-t * (0.9 + 0.55 * k)) / k ** 1.2
        hammer = 1 - np.exp(-t * 400)
        return lowpass(tone * hammer, 2600) * velocity

    pos = 0.0
    for name, beats in melody:
        s = int(pos * beat * SR)
        tone = piano(note(name), 5, 0.11)
        out[:, s:s + len(tone)] += tone * np.array([[0.55], [0.45]])
        pos += beats
    for b, chord in enumerate(bars):
        s = int((1 + b * 3) * beat * SR)
        for j, name in enumerate(chords[chord]):
            tone = piano(note(name), 5, 0.045)
            off = int(j * 0.06 * SR)  # gently rolled
            out[:, s + off:s + off + len(tone)] += tone * np.array([[0.45], [0.55]])
    return loop(reverb(out, 4.0, 0.42), length)


def save(name, stereo):
    stereo = stereo / np.max(np.abs(stereo)) * 0.6  # leave headroom; the app plays it quietly anyway
    os.makedirs(OUT, exist_ok=True)
    sf.write(f'{OUT}/{name}.mp3', stereo.T, SR, format='MP3', subtype='MPEG_LAYER_III')
    print(f'▸ {name:8} {stereo.shape[1] / SR:5.1f}s  {os.path.getsize(f"{OUT}/{name}.mp3") / 1e3:5.0f} KB')


if __name__ == '__main__':
    save('pad', pad())
    save('hymn', hymn())
