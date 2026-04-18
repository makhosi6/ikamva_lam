#!/usr/bin/env python3
"""Convert Kokoro voices-v1.0.bin (NumPy NPZ) to voices.json for kokoro_tts_flutter."""

import argparse
import json
import sys

try:
    import numpy as np
except ImportError as e:
    print("Requires numpy: pip install numpy", file=sys.stderr)
    raise SystemExit(1) from e


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("voices_bin", help="Path to voices-v1.0.bin")
    p.add_argument("out_json", help="Output voices.json path")
    args = p.parse_args()

    data = np.load(args.voices_bin)
    all_voices = {k: np.asarray(v).tolist() for k, v in data.items()}
    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump(all_voices, f)

    print(f"Wrote {len(all_voices)} voices to {args.out_json}")


if __name__ == "__main__":
    main()
