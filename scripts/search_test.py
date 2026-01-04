#!/usr/bin/env python3
"""Test semantic search on recipe embeddings."""

import json
import numpy as np
import hnswlib
from pathlib import Path
import mlx.core as mx
from mlx_embeddings.utils import load

RECIPES_JSON = Path("allrecipes-archive/allrecipes.com_database_12042020000000.json")
EMBEDDINGS_FILE = Path("recipe_embeddings.npz")
INDEX_FILE = Path("recipe_index.bin")

def load_or_build_index(embeddings: np.ndarray) -> hnswlib.Index:
    """Load existing index or build a new one."""
    dim = embeddings.shape[1]
    num_elements = embeddings.shape[0]

    index = hnswlib.Index(space='cosine', dim=dim)

    if INDEX_FILE.exists():
        print("Loading existing index...")
        index.load_index(str(INDEX_FILE), max_elements=num_elements)
    else:
        print("Building new index...")
        index.init_index(max_elements=num_elements, ef_construction=200, M=16)
        index.add_items(embeddings, np.arange(num_elements))
        index.set_ef(50)  # ef should be > k
        index.save_index(str(INDEX_FILE))
        print(f"Index saved to {INDEX_FILE}")

    return index

def embed_query(query: str, model, tokenizer) -> np.ndarray:
    """Generate embedding for a search query."""
    input_ids = tokenizer.encode(query, return_tensors="mlx")
    outputs = model(input_ids)
    embedding = outputs.text_embeds[0].astype(mx.float32)
    mx.eval(embedding)
    return np.array(embedding)

def search(query: str, index: hnswlib.Index, recipes: list, model, tokenizer, k: int = 5):
    """Search for recipes matching the query."""
    query_embedding = embed_query(query, model, tokenizer)
    labels, distances = index.knn_query(query_embedding.reshape(1, -1), k=k)

    print(f"\n🔍 Query: \"{query}\"")
    print("-" * 60)

    for i, (idx, dist) in enumerate(zip(labels[0], distances[0])):
        recipe = recipes[idx]
        score = 1 - dist  # Convert distance to similarity
        recipe_id = recipe.get('id', str(idx))
        print(f"\n{i+1}. [{score:.3f}] {recipe['title']}")
        print(f"   ID: {recipe_id}")
        if recipe.get('description'):
            desc = recipe['description'][:150]
            if len(recipe['description']) > 150:
                desc += "..."
            print(f"   {desc}")
        if recipe.get('rating'):
            print(f"   ⭐ Rating: {float(recipe['rating']):.1f}")

def main():
    # Load recipes
    print("Loading recipes...")
    with open(RECIPES_JSON) as f:
        recipes = json.load(f)
    print(f"Loaded {len(recipes)} recipes")

    # Load embeddings
    print("\nLoading embeddings...")
    data = np.load(EMBEDDINGS_FILE)
    embeddings = data['embeddings']
    print(f"Embeddings shape: {embeddings.shape}")

    # Build/load index
    index = load_or_build_index(embeddings)

    # Load embedding model
    print("\nLoading embedding model...")
    model, tokenizer = load("mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ")
    print("Model loaded!")

    # Interactive search
    print("\n" + "=" * 60)
    print("Recipe Semantic Search")
    print("Type a query to search, or 'quit' to exit")
    print("=" * 60)

    while True:
        try:
            query = input("\n> ").strip()
            if query.lower() in ('quit', 'exit', 'q'):
                break
            if not query:
                continue
            search(query, index, recipes, model, tokenizer)
        except KeyboardInterrupt:
            break

    print("\nGoodbye!")

if __name__ == "__main__":
    main()
