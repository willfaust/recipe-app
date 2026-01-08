# Recipe Semantic Search

A semantic search engine for recipes powered by [MLX](https://github.com/ml-explore/mlx) on Apple Silicon. Search through 25,000+ NYTimes Cooking recipes using natural language queries like "healthy breakfast with eggs" or "chocolate dessert for parties".

## Features

- **Semantic Search**: Find recipes by meaning, not just keywords
- **GPU-Accelerated**: Uses Apple Silicon GPU via MLX for fast inference and search
- **Native macOS App**: SwiftUI app with modern glass-effect design
- **Offline**: All processing happens locally on your device
- **Standalone Bundle**: Distributable .app with all resources embedded

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Query                           │
│                   "chocolate pancakes"                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                  Qwen3-Embedding Model                      │
│              (0.6B params, 4-bit quantized)                 │
│                                                             │
│  Instruct: Find recipes matching this description           │
│  Query: chocolate pancakes                                  │
│                           │                                 │
│                           ▼                                 │
│                   [1024-dim embedding]                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              GPU-Accelerated Vector Search                  │
│                                                             │
│    query_embedding @ recipe_embeddings.T → similarities     │
│                           │                                 │
│                           ▼                                 │
│                   Top-K results by cosine similarity        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                     Search Results                          │
│                                                             │
│  1. [0.747] Double Chocolate Pancakes                       │
│  2. [0.746] Decadent Chocolate Pancakes                     │
│  3. [0.725] Mini Chocolate Chip Pancakes                    │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
recipe-project/
├── RecipeApp/              # SwiftUI macOS application
│   └── Sources/
│       └── RecipeApp/
│           ├── Views/      # SwiftUI views
│           ├── Models/     # Data models
│           ├── Services/   # Search engine
│           ├── Config/     # Path configuration
│           └── MLX/        # ML model implementation
├── nytimes-archive/        # NYTimes recipe data (not in git)
│   ├── nytimes_recipes.json
│   ├── recipe_embeddings.bin
│   └── recipes/images-small/
├── build-app.sh            # Build standalone .app bundle
└── build/                  # Build output (not in git)
```

## Requirements

- macOS 15.0+ (Apple Silicon)
- Xcode 16.0+ with Swift 6
- ~2GB disk space for model weights
- ~100MB for recipe embeddings

## Quick Start

### Option 1: Run Pre-built App

Download `RecipeApp.tar.gz`, extract, and run:

```bash
tar -xzf RecipeApp.tar.gz
open RecipeApp.app
```

### Option 2: Build from Source

1. Clone the repository and obtain the NYTimes recipe data
2. Build the standalone app:

```bash
./build-app.sh
open build/RecipeApp.app
```

## Data Setup (for building from source)

The `nytimes-archive/` directory should contain:

```
nytimes-archive/
├── nytimes_recipes.json       # Recipe database (~75MB)
├── recipe_embeddings.bin      # Pre-computed embeddings (~98MB)
└── recipes/
    └── images-small/          # WebP thumbnails (~727MB)
        ├── 12345.webp
        └── ...
```

### Recipe JSON Format

```json
{
  "id": "12345",
  "name": "chocolate-chip-cookies",
  "title": "Chocolate Chip Cookies",
  "description": "Classic homemade cookies...",
  "rating": "5",
  "rating_count": "127",
  "images": ["12345.webp"],
  "ingredients": ["2 cups flour", "1 cup sugar", ...],
  "steps": [
    {"step": 1, "instruction": "Preheat oven to 375°F..."},
    ...
  ],
  "prep_time": "15",
  "cook_time": "12",
  "total_time": "27",
  "nutritional_information": {
    "calories": "150",
    "total_fat": "7 grams",
    "sodium": "95 milligrams",
    ...
  },
  "author": "Author Name",
  "cuisine": "American",
  "categories": ["desserts", "cookies"]
}
```

### Generating Embeddings

If you need to regenerate embeddings:

```bash
cd nytimes-archive
python3 -m venv venv
source venv/bin/activate
pip install mlx mlx-embeddings numpy tqdm

python generate_embeddings.py
```

## Build Standalone App Bundle

Creates a portable `.app` (~1.2GB) with all resources bundled:

```bash
./build-app.sh
```

The bundle includes:
- Recipe database and embeddings
- All recipe images (WebP compressed)
- MLX model weights and Metal library

To distribute:
```bash
cd build
tar -czvf RecipeApp.tar.gz RecipeApp.app
```

## Technical Details

### Embedding Model

Uses [Qwen3-Embedding-0.6B-4bit-DWQ](https://huggingface.co/mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ):
- 1024-dimensional embeddings
- 4-bit quantized (~335MB weights)
- Instruction-tuned for retrieval tasks

### Vector Search

GPU-accelerated matrix multiplication achieves sub-100ms search latency:

```swift
let similarities = matmul(queryEmbedding, embeddingsMatrix.T)
let topIndices = argSort(similarities)[(-k)...]
```

## Dependencies

**Swift:**
- [mlx-swift](https://github.com/ml-explore/mlx-swift) - Apple's ML framework
- [swift-transformers](https://github.com/huggingface/swift-transformers) - Tokenizers

**Python (for embedding generation):**
- mlx
- mlx-embeddings
- numpy
- tqdm

## Acknowledgments

- Recipe data from [NYTimes Cooking](https://cooking.nytimes.com/)
- Embedding model: [Qwen3-Embedding-0.6B-4bit-DWQ](https://huggingface.co/mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ)
- MLX framework by [Apple](https://github.com/ml-explore/mlx)
