"""Generate short periodic harmonic wavetables for the FPGA piano voice.

These are synthesized Fourier-series cycles, not recordings of notes. The
FPGA reads them at a variable DDS phase and applies its own time envelopes.
"""

from pathlib import Path
import math


TABLE_SIZE = 1024
PEAK = 6800
HARMONICS = {
    "attack": (1.0, 0.56, 0.34, 0.23, 0.15, 0.10, 0.065, 0.035),
    "body":   (1.0, 0.36, 0.17, 0.085, 0.042, 0.020, 0.009, 0.003),
    "tail":   (1.0, 0.20, 0.055, 0.012, 0.002, 0.0, 0.0, 0.0),
}


def series(weights, index):
    angle = 2 * math.pi * index / TABLE_SIZE
    return sum(weight * math.sin(harmonic * angle)
               for harmonic, weight in enumerate(weights, start=1))


def main():
    target = Path(__file__).resolve().parents[1] / "src" / "mem"
    attack_peak = max(abs(series(HARMONICS["attack"], i))
                      for i in range(TABLE_SIZE))
    scale = PEAK / attack_peak
    for name, weights in HARMONICS.items():
        samples = [round(scale * series(weights, i))
                   for i in range(TABLE_SIZE)]
        path = target / f"piano_{name}_1024x16.mem"
        path.write_text("".join(f"{value & 0xffff:04x}\n"
                                for value in samples), encoding="ascii")
        print(f"{name}: min={min(samples)} max={max(samples)} {path}")


if __name__ == "__main__":
    main()

