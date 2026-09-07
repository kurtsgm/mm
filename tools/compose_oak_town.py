"""Original Oaktown folk loop: Morning in Oaktown / 橡鎮晨光.

G major, 6/8, dotted-quarter = 72; 64 bars, 106.667 seconds.
All score positions and durations use eighth notes. No recordings or samples.
Run with Python + requirements-music.txt, alongside compose_oak_wild.py.
"""

from pathlib import Path

import numpy as np
import soundfile as sf

from compose_oak_wild import RATE, envelope, hz, lowpass


EIGHTH = 60 / 72 / 3
BAR = 6 * EIGHTH
BARS = 64
FRAMES = round(BARS * BAR * RATE)
OUT = Path(__file__).resolve().parents[1] / "content/audio/music/oak_town_morning.ogg"

# Guitar voicings sit below the recorder, with open tonic/dominant basses.
CHORDS = {
    "G": (43, [55, 62, 67, 71]),
    "D": (38, [57, 62, 66, 69]),
    "Em": (40, [55, 59, 64, 67]),
    "C": (36, [55, 60, 64, 67]),
    "Am": (45, [57, 60, 64, 69]),
    "Bm": (47, [54, 59, 62, 66]),
    "D7": (38, [57, 60, 66, 69]),
}
VERSE = ["G", "D", "Em", "C", "G", "Am", "D7", "G",
         "C", "G", "Am", "D", "Em", "C", "D7", "G"]
BRIDGE = ["C", "G", "Am", "D", "Bm", "Em", "C", "D7",
          "C", "G", "Am", "Em", "C", "G", "D7", "D7"]
INTRO = ["G", "D", "C", "D7"]
INTERLUDE = ["Em", "C", "G", "D", "Am", "C", "D7", "D7"]
OUTRO = ["C", "G", "D7", "D7"]
PROGRESSION = INTRO + VERSE + BRIDGE + INTERLUDE + VERSE + OUTRO

# A singable dotted-quarter motif; breathing space invites accordion replies.
MELODY_A = [
    [(71, 2), (74, 1), (79, 2), (78, 1)],
    [(78, 2), (76, 1), (74, 2), (None, 1)],
    [(76, 2), (79, 1), (78, 1), (76, 1), (74, 1)],
    [(76, 3), (72, 2), (None, 1)],
    [(71, 2), (74, 1), (79, 2), (74, 1)],
    [(76, 2), (72, 1), (69, 2), (None, 1)],
    [(69, 1), (72, 1), (74, 1), (78, 2), (76, 1)],
    [(74, 1), (71, 1), (67, 2), (None, 2)],
    [(76, 2), (79, 1), (84, 2), (83, 1)],
    [(83, 2), (81, 1), (79, 2), (None, 1)],
    [(81, 2), (79, 1), (76, 2), (72, 1)],
    [(74, 4), (None, 2)],
    [(76, 2), (79, 1), (83, 2), (79, 1)],
    [(79, 2), (76, 1), (72, 2), (None, 1)],
    [(74, 2), (72, 1), (69, 1), (66, 1), (69, 1)],
    [(67, 4), (None, 2)],
]
MELODY_B = [
    [(79, 3), (76, 2), (72, 1)],
    [(74, 2), (71, 1), (67, 2), (None, 1)],
    [(69, 2), (72, 1), (76, 2), (79, 1)],
    [(78, 4), (None, 2)],
    [(78, 2), (74, 1), (71, 2), (74, 1)],
    [(79, 3), (76, 2), (None, 1)],
    [(76, 2), (79, 1), (84, 2), (83, 1)],
    [(81, 2), (78, 1), (74, 2), (None, 1)],
    [(79, 2), (76, 1), (72, 2), (76, 1)],
    [(74, 3), (71, 2), (None, 1)],
    [(72, 2), (76, 1), (81, 2), (79, 1)],
    [(79, 3), (76, 2), (None, 1)],
    [(76, 2), (72, 1), (67, 2), (72, 1)],
    [(71, 2), (74, 1), (79, 2), (None, 1)],
    [(78, 2), (76, 1), (74, 2), (72, 1)],
    [(69, 3), (None, 3)],
]


def guitar(note, length, rng, bass=False):
    """Damped string modes with a soft fingertip attack and warm body."""
    t = np.arange(round(length * RATE)) / RATE
    signal = np.zeros_like(t)
    frequency = hz(note)
    for partial in range(1, 19):
        strength = np.sin(partial * np.pi * 0.21) / partial ** (1.6 if bass else 1.25)
        decay = (0.65 if bass else 1.0) / (1 + partial * 0.19)
        phase = 2 * np.pi * frequency * partial * (1 + partial ** 2 * 0.000008) * t
        signal += strength * np.sin(phase) * np.exp(-t / decay)
    signal += lowpass(rng.normal(size=len(t)), 1600 if bass else 2900) * np.exp(-t / 0.012) * 0.025
    return signal * envelope(t, length, 0.005, 0.07)


def recorder(note, length, rng):
    t = np.arange(round(length * RATE)) / RATE
    vibrato = 0.0017 * np.sin(2 * np.pi * 4.8 * t) * np.minimum(t / 0.5, 1)
    phase = 2 * np.pi * hz(note) * np.cumsum(1 + vibrato) / RATE
    signal = np.sin(phase) + 0.13 * np.sin(2 * phase) + 0.065 * np.sin(3 * phase)
    signal += 0.023 * lowpass(rng.normal(size=len(t)), 3400)
    return signal * envelope(t, length, 0.036, 0.065)


def accordion(note, length):
    """Quiet paired reeds with slow bellows movement, kept below the flute."""
    t = np.arange(round(length * RATE)) / RATE
    signal = np.zeros_like(t)
    for detune in (-0.0011, 0.0011):
        phase = 2 * np.pi * hz(note) * (1 + detune) * t
        for partial in range(1, 10):
            signal += np.sin(partial * phase) / partial ** 1.65 * 0.5
    bellows = 0.91 + 0.09 * np.sin(np.pi * t / length)
    return signal * envelope(t, length, 0.065, 0.10) * bellows


def bell(note):
    t = np.arange(round(2.5 * RATE)) / RATE
    signal = np.zeros_like(t)
    for ratio, gain, decay in [(1, 1, 0.7), (2.76, 0.25, 0.28), (5.4, 0.055, 0.12)]:
        signal += gain * np.sin(2 * np.pi * hz(note) * ratio * t) * np.exp(-t / decay)
    return signal * envelope(t, 2.5, 0.002, 0.08)


def percussion(rng, shaker=False, high=False):
    length = 0.11 if shaker else 0.4
    t = np.arange(round(length * RATE)) / RATE
    noise = rng.normal(size=len(t))
    if shaker:
        signal = (lowpass(noise, 7600) - lowpass(noise, 2700)) * np.exp(-t / 0.024)
    else:
        phase = 2 * np.pi * ((155 if high else 90) * t + 1.8 * (1 - np.exp(-28 * t)))
        signal = np.sin(phase) * np.exp(-t / (0.065 if high else 0.12))
        signal += 0.22 * lowpass(noise, 1900) * np.exp(-t / 0.02)
    return signal * envelope(t, length, 0.003, 0.025)


def render():
    assert len(PROGRESSION) == BARS
    assert all(sum(duration for _, duration in phrase) == 6 for phrase in MELODY_A + MELODY_B)
    rng = np.random.default_rng(20260908)
    dry = np.zeros((FRAMES, 2))
    send = np.zeros_like(dry)

    def add(signal, when, gain, pan=0, room=0.2):
        start = round(when * RATE) % FRAMES
        stereo = signal[:, None] * gain * np.array([
            np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)])
        first = min(len(signal), FRAMES - start)
        dry[start:start + first] += stereo[:first]
        send[start:start + first] += stereo[:first] * room
        if first < len(signal):
            dry[:len(signal) - first] += stereo[first:]
            send[:len(signal) - first] += stereo[first:] * room

    for bar, name in enumerate(PROGRESSION):
        root, chord = CHORDS[name]
        base = bar * BAR
        sparse = bar < 4 or 36 <= bar < 44 or bar >= 60
        intensity = 0.80 if sparse else 0.94 if bar < 20 else 1.0
        for pulse, index in enumerate([0, 2, 1, 0, 3, 2]):
            accent = [0.19, 0.14, 0.15, 0.17, 0.14, 0.15][pulse]
            add(guitar(chord[index], 1.7, rng), base + pulse * EIGHTH + rng.uniform(0.004, 0.013),
                accent * intensity * rng.uniform(0.94, 1.05), -0.30, 0.18)
        for pulse, pitch in [(0, root), (3, root + 7)]:
            add(guitar(pitch, 1.35, rng, bass=True), base + pulse * EIGHTH + 0.003,
                0.27 * intensity, -0.04, 0.08)
        if 4 <= bar < 60:
            add(percussion(rng), base + 0.009, 0.058 * intensity, 0.10, 0.08)
            add(percussion(rng, high=True), base + 3 * EIGHTH + 0.014, 0.033 * intensity, 0.16, 0.08)
            for pulse in range(6):
                add(percussion(rng, shaker=True), base + pulse * EIGHTH + 0.02,
                    (0.024 if pulse in (0, 3) else 0.014) * intensity, 0.30, 0.06)
        # Brief reed chords on the second lilt; omit alternate bars for air.
        if not sparse and bar % 2 == 0:
            for pitch in chord[1:3]:
                add(accordion(pitch, 1.8 * EIGHTH), base + 3.1 * EIGHTH, 0.024, 0.26, 0.21)
        if bar in (0, 12, 20, 28, 44, 52, 60):
            add(bell(chord[2] + 24), base + 0.035, 0.035, 0.40, 0.37)

    for start_bar, melody in [(4, MELODY_A), (20, MELODY_B), (44, MELODY_A)]:
        for offset, phrase in enumerate(melody):
            position = 0
            chord = CHORDS[PROGRESSION[start_bar + offset]][1]
            for pitch, duration in phrase:
                when = (start_bar + offset) * BAR + position * EIGHTH + 0.018
                if pitch is not None:
                    length = duration * EIGHTH - 0.05
                    if start_bar == 44 and offset in (0, 4, 8, 12) and position == 0:
                        # Short lower-neighbor ornament in the final statement.
                        add(recorder(pitch - 2, 0.08, rng), when, 0.065, 0.01, 0.27)
                        when += 0.06
                        length -= 0.06
                    add(recorder(pitch, length, rng), when, rng.uniform(0.105, 0.119), 0.01, 0.27)
                elif duration >= 1 and offset % 2 == 1:
                    add(accordion(chord[2], duration * EIGHTH - 0.04), when, 0.062, 0.25, 0.24)
                position += duration

    # Opening guitar greeting; the middle passage lets the accordion lead.
    for start_bar, phrases in [(0, MELODY_A[:4]), (36, MELODY_B[8:16])]:
        for offset, phrase in enumerate(phrases):
            position = 0
            # Follow the interlude's own chord tones to keep this answer settled.
            chord = CHORDS[PROGRESSION[start_bar + offset]][1]
            for index, (pitch, duration) in enumerate(phrase):
                if pitch is not None:
                    when = (start_bar + offset) * BAR + position * EIGHTH + 0.018
                    tone = chord[[2, 3, 2, 1, 0, 1][index % 6]]
                    if start_bar == 0:
                        add(guitar(tone, 1.8, rng), when, 0.21, 0.22, 0.23)
                    else:
                        add(accordion(tone, duration * EIGHTH - 0.055), when, 0.086, 0.18, 0.25)
                position += duration
    # A light dominant pickup leads back to the tonic at the loop start.
    for pulse, pitch in [(3, 69), (4, 66), (5, 62)]:
        add(guitar(pitch, 1.5, rng), 63 * BAR + pulse * EIGHTH + 0.015, 0.14, 0.22, 0.22)

    # Circular releases and short room reflections preserve the full loop length.
    warm = lowpass(np.concatenate([send[-RATE:], send], axis=0).T, 3900).T[RATE:]
    mix = dry.copy()
    for tap in range(1, 25):
        delay = round((0.035 + tap * 0.0539 + (tap % 3) * 0.0083) * RATE)
        reflected = np.roll(warm, delay, axis=0)
        mix += (reflected[:, ::-1] if tap % 2 else reflected) * (0.26 * np.exp(-tap / 6.5))
    mix -= mix.mean(axis=0)
    mix *= 10 ** (-4 / 20) / np.max(np.abs(mix))
    assert np.isfinite(mix).all()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with sf.SoundFile(OUT, "w", samplerate=RATE, channels=2,
                      format="OGG", subtype="VORBIS", compression_level=0.5) as stream:
        for start in range(0, FRAMES, 8192):
            stream.write(mix[start:start + 8192])
    print(f"Rendered {OUT}: {FRAMES / RATE:.3f}s, {OUT.stat().st_size / 1024:.0f} KiB")
    print(f"PCM peak: {20 * np.log10(np.max(np.abs(mix))):.2f} dBFS; "
          f"RMS: {20 * np.log10(np.sqrt(np.mean(mix ** 2))):.2f} dBFS; "
          f"loop boundary step: {np.max(np.abs(mix[0] - mix[-1])):.6f}")


if __name__ == "__main__":
    render()
