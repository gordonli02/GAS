"""Speeds up a looping sound without changing its pitch (WSOLA), keeping it loopable.

G wanted the dispenser motor at 1.5x speed (as in the web build, which played it at
playback rate 1.5) but at its original pitch. Usage:
    python tools/time_stretch_loop.py assets/audio/dispense_loop.wav assets/audio/dispense_loop_fast.wav 1.5
Prints the rhythm period and spectral peak of the source, the naive 1.5x playback and
the result, so the change can be checked by numbers as well as by ear.
"""
import sys
import wave

import numpy as np


def read(path):
    w = wave.open(path)
    assert w.getnchannels() == 1 and w.getsampwidth() == 2, "mono 16-bit only"
    sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return x, sr


def write(path, x, sr):
    y = np.clip(np.round(x * 32767.0), -32768, 32767).astype(np.int16)
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(y.tobytes())
    w.close()


def wsola(x, speed, n=1024, tolerance=384):
    """Overlap-add of windowed segments taken every n/2*speed input samples, each nudged
    within +-tolerance to line up with the natural continuation of the previous one."""
    hs = n // 2
    ha = hs * speed
    win = np.hanning(n)
    frames = int((len(x) - n - 2 * tolerance) / ha)
    out = np.zeros(frames * hs + n)
    norm = np.zeros_like(out)
    prev = tolerance
    for k in range(frames):
        target = int(round(tolerance + k * ha))
        if k == 0:
            best = target
        else:
            natural = x[prev + hs: prev + hs + n]
            lo, hi = target - tolerance, target + tolerance
            region = x[lo: hi + n]
            # cross-correlation of the natural continuation against candidate starts
            corr = np.correlate(region, natural, mode="valid")
            best = lo + int(np.argmax(corr))
        out[k * hs: k * hs + n] += x[best: best + n] * win
        norm[k * hs: k * hs + n] += win
        prev = best
    norm[norm < 1e-6] = 1.0
    return out / norm


def loopable(x, sr, speed):
    """Stretch three copies end to end, keep one period from the middle and crossfade
    its start into what follows it, so the end runs straight back into the start."""
    period = int(round(len(x) / speed))
    y = wsola(np.tile(x, 4), speed)
    start = period
    fade = int(sr * 0.012)
    seg = y[start: start + period].copy()
    after = y[start + period: start + period + fade]
    r = np.linspace(0.0, 1.0, fade)
    seg[:fade] = after * (1.0 - r) + seg[:fade] * r
    return seg


def describe(name, x, sr):
    env = np.abs(x)
    k = int(sr * 0.005)
    env = np.convolve(env, np.ones(k) / k, "same")
    env -= env.mean()
    ac = np.correlate(env, env, "full")[len(env) - 1:]
    lo, hi = int(sr * 0.02), int(sr * 0.3)
    period = (lo + int(np.argmax(ac[lo:hi]))) / sr * 1000
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1 / sr)
    band = (f > 60) & (f < 2000)
    peak = f[band][np.argmax(spec[band])]
    print(f"{name:>16}: {len(x) / sr:6.3f} s  rhythm {period:6.1f} ms  low peak {peak:6.1f} Hz  "
          f"centroid {(spec * f).sum() / spec.sum():7.0f} Hz")


def main():
    src, dst, speed = sys.argv[1], sys.argv[2], float(sys.argv[3])
    x, sr = read(src)
    y = loopable(x, sr, speed)
    naive = np.interp(np.arange(0, len(x), speed), np.arange(len(x)), x)
    describe("source", x, sr)
    describe(f"{speed}x playback", naive, sr)
    describe("stretched", y, sr)
    # seam check: the jump from the last sample back to the first, against typical steps
    steps = np.abs(np.diff(y))
    print(f"loop seam step {abs(y[0] - y[-1]):.4f}  (median step {np.median(steps):.4f}, 99th pct {np.percentile(steps, 99):.4f})")
    write(dst, y, sr)
    print("wrote", dst)


if __name__ == "__main__":
    main()
