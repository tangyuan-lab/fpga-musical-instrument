"""Generate short periodic harmonic wavetables for the FPGA piano voice.

These are synthesized Fourier-series cycles, not recordings of notes. The
FPGA reads them at a variable DDS phase and applies its own time envelopes.
"""

from pathlib import Path
import math


TABLE_SIZE = 1024
TARGET_RMS = 3300
HARMONICS = {
    "attack": (1.0, 0.72, 0.55, 0.42, 0.32, 0.22, 0.14, 0.08),
    "body":   (1.0, 0.50, 0.32, 0.20, 0.13, 0.075, 0.04, 0.02),
    "tail":   (1.0, 0.36, 0.18, 0.085, 0.035, 0.012, 0.004, 0.0),
}


def series(weights, index):
    angle = 2 * math.pi * index / TABLE_SIZE
    return sum(weight * math.sin(harmonic * angle)
               for harmonic, weight in enumerate(weights, start=1))


def main():
    target = Path(__file__).resolve().parents[1] / "src" / "mem"
    for name, weights in HARMONICS.items():
        mean_square = sum(series(weights, i) ** 2
                          for i in range(TABLE_SIZE)) / TABLE_SIZE
        scale = TARGET_RMS / math.sqrt(mean_square)
        samples = [round(scale * series(weights, i))
                   for i in range(TABLE_SIZE)]
        path = target / f"piano_{name}_1024x16.mem"
        path.write_text("".join(f"{value & 0xffff:04x}\n"
                                for value in samples), encoding="ascii")
        print(f"{name}: min={min(samples)} max={max(samples)} {path}")


if __name__ == "__main__":
    main()

