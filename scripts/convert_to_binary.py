#!/usr/bin/env python3
"""Convert NPZ embeddings to binary format for Swift."""

import numpy as np
import struct
from pathlib import Path

NPZ_FILE = Path("recipe_embeddings.npz")
BIN_FILE = Path("recipe_embeddings.bin")

def main():
    print("Loading embeddings...")
    data = np.load(NPZ_FILE)
    embeddings = data['embeddings'].astype(np.float32)

    count, dim = embeddings.shape
    print(f"Shape: {count} x {dim}")

    print(f"Writing to {BIN_FILE}...")
    with open(BIN_FILE, 'wb') as f:
        # Header: count (int32), dim (int32)
        f.write(struct.pack('<i', count))
        f.write(struct.pack('<i', dim))
        # Data: flat float32 array
        f.write(embeddings.tobytes())

    size_mb = BIN_FILE.stat().st_size / 1024 / 1024
    print(f"Done! File size: {size_mb:.1f} MB")

if __name__ == "__main__":
    main()
