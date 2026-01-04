#!/usr/bin/env python3
"""Generate embeddings for all recipes using Qwen3-Embedding-0.6B-4bit-DWQ"""

import json
import numpy as np
from pathlib import Path
from tqdm import tqdm
import mlx.core as mx
from mlx_embeddings.utils import load

RECIPES_JSON = Path("allrecipes-archive/allrecipes.com_database_12042020000000.json")
EMBEDDINGS_FILE = Path("recipe_embeddings.npz")
BATCH_SIZE = 32

def create_search_text(recipe: dict) -> str:
    """Create searchable text from recipe fields."""
    parts = []

    # Title is most important
    if recipe.get("title"):
        parts.append(recipe["title"])

    # Description provides context
    if recipe.get("description"):
        parts.append(recipe["description"])

    # Ingredients are key for search
    ingredients = recipe.get("ingredients", [])
    if ingredients:
        parts.append("Ingredients: " + ", ".join(ingredients[:10]))  # Limit to first 10

    return " ".join(parts)

def main():
    print("Loading recipes...")
    with open(RECIPES_JSON) as f:
        recipes = json.load(f)
    print(f"Loaded {len(recipes)} recipes")

    print("\nLoading embedding model...")
    model, tokenizer = load("mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ")
    print("Model loaded!")

    # Prepare texts
    print("\nPreparing search texts...")
    texts = [create_search_text(r) for r in recipes]
    recipe_ids = [r.get("id", str(i)) for i, r in enumerate(recipes)]

    # Generate embeddings in batches
    print(f"\nGenerating embeddings (batch size: {BATCH_SIZE})...")
    all_embeddings = []

    for i in tqdm(range(0, len(texts), BATCH_SIZE)):
        batch_texts = texts[i:i + BATCH_SIZE]
        batch_embeddings = []

        for text in batch_texts:
            # Truncate very long texts
            text = text[:2000]
            input_ids = tokenizer.encode(text, return_tensors="mlx")
            outputs = model(input_ids)
            embedding = outputs.text_embeds[0]
            # Convert to float32 for numpy compatibility and evaluate
            embedding = embedding.astype(mx.float32)
            mx.eval(embedding)
            batch_embeddings.append(np.array(embedding))

        all_embeddings.extend(batch_embeddings)
        mx.metal.clear_cache()  # Clear GPU cache periodically

    # Stack into numpy array
    embeddings_array = np.stack(all_embeddings)
    print(f"\nEmbeddings shape: {embeddings_array.shape}")

    # Save embeddings and metadata
    print(f"\nSaving to {EMBEDDINGS_FILE}...")
    np.savez_compressed(
        EMBEDDINGS_FILE,
        embeddings=embeddings_array,
        recipe_ids=np.array(recipe_ids),
    )

    print("Done!")
    print(f"File size: {EMBEDDINGS_FILE.stat().st_size / 1024 / 1024:.1f} MB")

if __name__ == "__main__":
    main()
