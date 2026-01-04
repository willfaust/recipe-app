# Recipe Semantic Search

A semantic search engine for recipes powered by [MLX](https://github.com/ml-explore/mlx) on Apple Silicon. Search through 50,000+ recipes using natural language queries like "healthy breakfast with eggs" or "chocolate dessert for parties".

## Features

- **Semantic Search**: Find recipes by meaning, not just keywords
- **GPU-Accelerated**: Uses Apple Silicon GPU via MLX for fast inference and search
- **Native macOS App**: SwiftUI app with modern design
- **CLI Tool**: Fast command-line interface for quick searches
- **Offline**: All processing happens locally on your device

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
├── RecipeApp/           # SwiftUI macOS application
│   └── Sources/
│       └── RecipeApp/
│           ├── Views/           # SwiftUI views
│           ├── Models/          # Data models
│           ├── Services/        # Search engine
│           └── MLX/             # ML model implementation
├── RecipeSearch/        # Command-line interface
│   └── Sources/
│       └── RecipeSearch/
│           └── main.swift
├── scripts/             # Python reference scripts
│   ├── generate_embeddings.py   # Batch embedding generation
│   ├── convert_to_binary.py     # Convert embeddings to binary
│   └── search_test.py           # Python search implementation
├── recipe-app.sh        # Launch GUI app (development)
├── recipe-search.sh     # Launch CLI
└── build-app.sh         # Build standalone .app bundle
```

## Requirements

- macOS 15.0+ (Apple Silicon)
- Xcode 16.0+ with Swift 6
- ~2GB disk space for model weights
- ~500MB for recipe embeddings

## Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd recipe-project
```

### 2. Download Recipe Data

Download the [AllRecipes.com Archive](https://archive.org/details/allrecipes.com_recipes_12042020000000) and extract it to `allrecipes-archive/`.

#### Required Directory Structure

```
allrecipes-archive/
├── allrecipes.com_database_12042020000000.json   # Main recipe database (~115MB)
└── images/
    └── 250x250/                                   # Recipe thumbnails
        ├── 162924.jpg
        ├── 30613.jpg
        └── ...                                    # ~50k images
```

#### Recipe JSON Format

The main database is a JSON array of recipe objects with the following structure:

```json
{
  "id": "14581",
  "name": "marinated-veggies",
  "title": "Marinated Veggies",
  "description": "A healthy way to grill veggies! Makes a great sandwich too!",
  "rating": "4.48258686065674",
  "images": ["30613.jpg"],
  "categories": ["Appetizers and Snacks"],
  "ingredients": [
    "1/2 cup thickly sliced zucchini",
    "1/2 cup sliced red bell pepper",
    "1/2 cup olive oil",
    "..."
  ],
  "steps": [
    {
      "step": 1,
      "instruction": "Place the vegetables in a large bowl."
    },
    {
      "step": 2,
      "instruction": "Mix together olive oil, soy sauce, and lemon juice..."
    }
  ],
  "prep_time": "PT15M",
  "cook_time": "PT15M",
  "total_time": "PT1H",
  "nutritional_information": {
    "calories": "159",
    "servings": "8",
    "total_fat": "13.9g",
    "saturated_fat": "2.0g",
    "cholesterol": "0mg",
    "sodium": "909mg",
    "potassium": "357mg",
    "total_carbohydrate": "7.9g",
    "dietry_fibre": "1.6g",
    "protein": "3.2g",
    "sugars": "2g",
    "vitamin_a": "441IU",
    "vitamin_c": "42mg",
    "calcium": "14mg",
    "iron": "1mg"
  }
}
```

> **Note:** Time fields use ISO 8601 duration format (e.g., `PT15M` = 15 minutes, `PT1H` = 1 hour).

### 3. Generate Embeddings

You can either download pre-generated embeddings or generate them yourself.

**Option A: Generate with Python (recommended for customization)**

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install mlx mlx-embeddings numpy

# Generate embeddings (~30 min on M1)
python scripts/generate_embeddings.py

# Convert to binary format for Swift
python scripts/convert_to_binary.py
```

**Option B: Generate with Swift CLI**

```bash
cd RecipeSearch
swift build -c release
# (embedding generation via Swift not yet implemented)
```

### 4. Build the Applications

**GUI App (development):**
```bash
./recipe-app.sh
```

**CLI Tool:**
```bash
cd RecipeSearch
swift build -c release
```

### 5. Build Standalone App Bundle (Optional)

To create a portable `.app` that can run on any Apple Silicon Mac without setup:

```bash
./build-app.sh
```

This creates `build/RecipeApp.app` (~1.7GB) with all resources bundled:
- Recipe database and embeddings
- All recipe images
- MLX model weights and Metal library

To distribute:
```bash
cd build && zip -r RecipeApp.zip RecipeApp.app
```

## Usage

### macOS App

Launch the GUI application:

```bash
./recipe-app.sh
```

Or build and run directly:

```bash
cd RecipeApp
swift build -c release
./.build/release/RecipeApp
```

Features:
- Live search as you type
- Recipe grid with thumbnails
- Detailed view with ingredients and nutrition facts
- Dark mode support

### Command Line

```bash
./recipe-search.sh
```

Or run directly:

```bash
cd RecipeSearch
swift run -c release
```

Example session:
```
> healthy breakfast eggs
1. [0.734] Veggie Egg White Omelet
2. [0.721] Healthy Banana Egg Pancakes
3. [0.718] Spinach and Egg Breakfast Wrap
...

> quit
```

## Technical Details

### Embedding Model

Uses [Qwen3-Embedding-0.6B-4bit-DWQ](https://huggingface.co/mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ), a 4-bit quantized version of [Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B) optimized for MLX:
- 1024-dimensional embeddings
- Instruction-tuned for retrieval tasks
- ~300MB quantized weights

### Instruction Prefix

For optimal retrieval quality, queries are prefixed with an instruction:

```
Instruct: Find recipes matching this description
Query: <user query>
```

This significantly improves result relevance for instruction-tuned embedding models.

### Vector Search

Search is performed via GPU-accelerated matrix multiplication:

```swift
let similarities = matmul(queryEmbedding, embeddingsMatrix.T)
let topIndices = argSort(similarities)[(-k)...]
```

This achieves sub-100ms search latency across 50k recipes on Apple Silicon.

## Dependencies

**Swift:**
- [mlx-swift](https://github.com/ml-explore/mlx-swift) - Apple's ML framework
- [swift-transformers](https://github.com/huggingface/swift-transformers) - Tokenizers
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - CLI parsing

**Python (for embedding generation):**
- mlx
- mlx-embeddings
- numpy

## Acknowledgments

- Recipe data from [AllRecipes.com Archive](https://archive.org/details/allrecipes.com_recipes_12042020000000)
- Embedding model: [Qwen3-Embedding-0.6B-4bit-DWQ](https://huggingface.co/mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ) by [MLX Community](https://huggingface.co/mlx-community), based on [Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B)
- MLX framework by [Apple](https://github.com/ml-explore/mlx)
