"""Render an original, seamless fantasy travelling tune; no sampled recordings.

Run with Python + requirements-music.txt.
Score: D Dorian, 6/8, dotted-quarter = 78, 64 bars (~98 seconds).
All note positions/durations below are in eighth notes.
"""

from pathlib import Path
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt


RATE = 44100
EIGHTH = 60 / 78 / 3
BAR = EIGHTH * 6
BARS = 64
FRAMES = round(BAR * BARS * RATE)
OUT = Path(__file__).resolve().parents[1] / "content/audio/music/oak_wild_bard.ogg"
RNG = np.random.default_rng(20260907)

# Close voicings leave space for the flute above and the open bass below.
CHORDS = {
    "Dm": (38, [62, 65, 69, 74]),
    "C": (36, [60, 64, 67, 72]),
    "G": (43, [59, 62, 67, 71]),
    "F": (41, [60, 65, 69, 72]),
    "Am": (45, [60, 64, 69, 72]),
}
VERSE = ["Dm", "Dm", "C", "G", "Dm", "F", "C", "Dm",
         "F", "C", "G", "Dm", "Am", "C", "G", "Dm"]
BRIDGE = ["F", "C", "G", "Dm", "F", "Am", "G", "G",
          "F", "C", "Am", "Dm", "F", "C", "G", "Dm"]
PROGRESSION = VERSE[:8] + VERSE + BRIDGE + VERSE[8:] + VERSE

# (MIDI pitch, eighth-note duration); None is a breath/rest.
MELODY_A = [
    [(74, 2), (77, 1), (79, 1), (81, 2)],
    [(81, 3), (79, 1), (77, 1), (76, 1)],
    [(76, 2), (79, 1), (84, 2), (83, 1)],
    [(81, 1), (79, 2), (83, 2), (None, 1)],
    [(81, 2), (79, 1), (77, 2), (74, 1)],
    [(77, 3), (81, 2), (84, 1)],
    [(83, 1), (79, 2), (76, 2), (72, 1)],
    [(74, 5), (None, 1)],
    [(81, 2), (84, 1), (86, 2), (84, 1)],
    [(84, 2), (79, 1), (76, 2), (79, 1)],
    [(83, 3), (81, 1), (79, 2)],
    [(81, 2), (77, 1), (74, 2), (None, 1)],
    [(76, 2), (81, 1), (84, 2), (81, 1)],
    [(79, 3), (76, 2), (72, 1)],
    [(74, 1), (79, 2), (83, 1), (81, 1), (79, 1)],
    [(77, 1), (76, 1), (74, 3), (None, 1)],
]
MELODY_B = [
    [(84, 3), (81, 2), (77, 1)],
    [(79, 2), (84, 1), (88, 2), (84, 1)],
    [(86, 2), (83, 1), (81, 2), (79, 1)],
    [(81, 4), (None, 2)],
    [(81, 1), (84, 2), (89, 2), (88, 1)],
    [(88, 2), (84, 1), (81, 3)],
    [(83, 2), (86, 1), (83, 2), (81, 1)],
    [(79, 4), (None, 2)],
    [(77, 2), (81, 1), (84, 2), (81, 1)],
    [(79, 3), (76, 1), (79, 2)],
    [(81, 2), (84, 1), (88, 2), (84, 1)],
    [(86, 3), (81, 2), (77, 1)],
    [(81, 2), (77, 1), (72, 2), (77, 1)],
    [(79, 2), (76, 1), (72, 2), (None, 1)],
    [(71, 1), (74, 1), (79, 1), (83, 2), (79, 1)],
    [(77, 1), (76, 1), (74, 3), (None, 1)],
]


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def lowpass(signal, cutoff):
    return sosfilt(butter(2, cutoff, fs=RATE, output="sos"), signal)


def envelope(t, duration, attack, release):
    return np.minimum(t / attack, 1) * np.clip((duration - t) / release, 0, 1)


def pluck(note, length, harp=False):
    """Decaying string modes, paired lute courses, and a quiet pick transient."""
    t = np.arange(round(length * RATE)) / RATE
    f = hz(note)
    signal = np.zeros_like(t)
    for partial in range(1, 16):
        if f * partial > RATE * 0.44:
            break
        decay = (1.55 if harp else 0.95) / (1 + partial * 0.17)
        strength = np.sin(partial * 0.23 * np.pi) / partial ** 1.45
        phase = RNG.uniform(-0.05, 0.05)
        mode = 2 * np.pi * f * partial * (1 + partial ** 2 * 0.000012) * t
        body = np.sin(mode + phase)
        if not harp:
            body = 0.58 * body + 0.42 * np.sin(mode * 1.0018 + phase)
        signal += strength * body * np.exp(-t / decay)
    pick = lowpass(RNG.normal(size=len(t)), 2800) * np.exp(-t / 0.009)
    signal += pick * (0.016 if harp else 0.035)
    return signal * envelope(t, length, 0.004, 0.07)


def flute(note, length):
    t = np.arange(round(length * RATE)) / RATE
    vibrato = 0.0025 * np.sin(2 * np.pi * 4.7 * t) * np.minimum(t / 0.45, 1)
    breath_drift = 0.0005 * np.sin(2 * np.pi * 1.3 * t)
    phase = 2 * np.pi * hz(note) * np.cumsum(1 + vibrato + breath_drift) / RATE
    signal = (np.sin(phase) + 0.19 * np.sin(2 * phase)
              + 0.075 * np.sin(3 * phase) + 0.025 * np.sin(4 * phase))
    air = lowpass(RNG.normal(size=len(t)), 3600)
    signal += air * 0.032
    return signal * envelope(t, length, 0.045, 0.09) * (0.97 + 0.03 * np.sin(13 * t))


def bowed(note, length):
    t = np.arange(round(length * RATE)) / RATE
    signal = np.zeros_like(t)
    for detune in [-0.0018, 0.0014]:
        phase = (2 * np.pi * hz(note) * (1 + detune) * t
                 + 0.11 * np.sin(2 * np.pi * 4.2 * t) + RNG.uniform(0, 6))
        for partial in range(1, 7):
            signal += np.sin(partial * phase) / partial ** 1.9
    return signal * envelope(t, length, 0.42, 0.55) * 0.5


def drum(high=False):
    length = 0.22 if high else 0.55
    t = np.arange(round(length * RATE)) / RATE
    f = 145 if high else 76
    phase = 2 * np.pi * (f * t + 2.5 * (1 - np.exp(-t * 25)))
    skin = np.sin(phase) * np.exp(-t / (0.055 if high else 0.14))
    skin += 0.27 * np.sin(phase * 1.59) * np.exp(-t / 0.065)
    noise = lowpass(RNG.normal(size=len(t)), 1800 if high else 650)
    return (skin + noise * np.exp(-t / 0.024) * 0.3) * envelope(t, length, 0.003, 0.025)


def render():
    dry = np.zeros((FRAMES, 2), dtype=np.float64)
    send = np.zeros_like(dry)

    def add(signal, when, gain, pan=0, room=0.2):
        # Wrap note releases into the beginning, including the last bar's tails.
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
        section = 0 if bar < 8 else 1 if bar < 24 else 2 if bar < 40 else 3 if bar < 48 else 4
        intensity = [0.78, 0.91, 1.0, 0.78, 0.95][section]
        base = bar * BAR
        # Two gently accented groups of three, with human timing and dynamics.
        for pulse, index in enumerate([0, 2, 1, 0, 3, 2]):
            gain = [0.155, 0.115, 0.12, 0.14, 0.11, 0.115][pulse]
            add(pluck(chord[index], 1.65), base + pulse * EIGHTH + RNG.uniform(0.003, 0.012),
                gain * intensity * RNG.uniform(0.92, 1.05), -0.32, 0.2)
        for pulse, pitch in [(0, root), (3, root + 7)]:
            add(pluck(pitch, 2.2), base + pulse * EIGHTH, 0.20 * intensity, -0.08, 0.12)
        if section != 0 or bar >= 4:
            add(drum(), base + 0.006, 0.083 * intensity, 0.10, 0.07)
            add(drum(True), base + 3 * EIGHTH + 0.012, 0.038 * intensity, 0.17, 0.09)
            if bar % 4 == 3:
                add(drum(True), base + 5 * EIGHTH, 0.024, 0.12, 0.09)
        # A restrained harp answer leaves the central melody uncluttered.
        if bar % 2 == 0:
            for pulse, pitch in [(0.04, chord[1] + 12), (1.55, chord[2] + 12), (3.08, chord[3] + 12)]:
                add(pluck(pitch, 2.8, harp=True), base + pulse * EIGHTH, 0.065 * intensity, 0.42, 0.42)
        if section in (2, 4) or (section == 1 and bar >= 16):
            for pitch, pan in [(chord[0] - 12, -0.52), (chord[2] - 12, 0.52)]:
                add(bowed(pitch, BAR + 0.65), base, 0.024 * intensity, pan, 0.4)

    for start_bar, melody in [(8, MELODY_A), (24, MELODY_B), (48, MELODY_A)]:
        for offset, phrase in enumerate(melody):
            position = 0
            for index, (pitch, duration) in enumerate(phrase):
                if pitch is not None:
                    when = (start_bar + offset) * BAR + position * EIGHTH + 0.018
                    # Sparse grace notes in the reprise give a played, bardic inflection.
                    if start_bar == 48 and offset in (0, 4, 8, 12) and index == 0:
                        add(flute(pitch + 2, 0.085), when, 0.095, -0.02, 0.3)
                        when += 0.07
                    length = duration * EIGHTH - 0.045
                    add(flute(pitch, length), when, RNG.uniform(0.108, 0.123), 0.04, 0.34)
                position += duration

    # Opening and instrumental interlude: the lute carries a lower, spacious answer.
    for start_bar, phrases in [(0, MELODY_A[:8]), (40, MELODY_A[8:])]:
        for offset, phrase in enumerate(phrases):
            position = 0
            for pitch, duration in phrase:
                if pitch is not None:
                    add(pluck(pitch - 12, 2.0), (start_bar + offset) * BAR + position * EIGHTH + 0.02,
                        0.18, 0.21, 0.3)
                position += duration

    # Circular room reflections keep ambience continuous at the native stream loop.
    # Filter with preceding audio so the reverb filter has no startup discontinuity.
    warm_send = lowpass(np.concatenate([send[-RATE:], send], axis=0).T, 4200).T[RATE:]
    wet = np.zeros_like(dry)
    for tap in range(1, 31):
        delay = round((0.047 + tap * 0.0617 + (tap % 3) * 0.0071) * RATE)
        reflected = np.roll(warm_send, delay, axis=0)
        if tap % 2:
            reflected = reflected[:, ::-1]
        wet += reflected * (0.29 * np.exp(-tap / 8.0))
    mix = dry + wet
    mix -= mix.mean(axis=0)
    mix *= 10 ** (-4.0 / 20) / np.max(np.abs(mix))
    assert np.isfinite(mix).all()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # Feed bounded blocks to libsndfile's Vorbis encoder (large writes can crash).
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
