import Foundation
import MLX
import Tokenizers
import ArgumentParser

// MARK: - Data Structures

struct Recipe: Codable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]?
    let rating: String?
    let images: [String]?
}

// MARK: - Vector Search (GPU-accelerated via MLX)

func searchTopK(query: MLXArray, embeddingsMatrix: MLXArray, k: Int) -> [(index: Int, similarity: Float)] {
    // query shape: [dim], embeddingsMatrix shape: [n, dim]
    // Compute cosine similarity: query @ embeddings.T (embeddings are already normalized)
    let queryNorm = sqrt(sum(query * query))
    let normalizedQuery = query / queryNorm

    // Matrix multiply: [1, dim] @ [dim, n] = [1, n]
    let similarities = matmul(normalizedQuery.reshaped([1, -1]), embeddingsMatrix.T).squeezed()

    // Get top-k indices
    let topIndices = argSort(similarities)[(-k)...]
    eval(topIndices)

    let indicesArray = topIndices.asArray(Int32.self).reversed()
    let simArray = similarities.asArray(Float.self)

    return indicesArray.map { idx in
        (index: Int(idx), similarity: simArray[Int(idx)])
    }
}

// MARK: - Embedding Generation

func generateEmbedding(text: String, model: EmbeddingModel, tokenizer: Tokenizer) -> MLXArray {
    // Use instruction prefix for better retrieval quality with Qwen3
    let queryWithInstruction = "Instruct: Find recipes matching this description\nQuery: \(text)"
    var encoded = tokenizer.encode(text: queryWithInstruction, addSpecialTokens: true)

    // Qwen3 requires the EOS/PAD token (151643) at the end for last-token pooling
    let qwen3PadToken = 151643
    if encoded.last != qwen3PadToken {
        encoded.append(qwen3PadToken)
    }

    let inputIds = MLXArray(encoded)
    let batchedInput = inputIds.reshaped([1, encoded.count])
    let attentionMask = ones([1, encoded.count]).asType(.int32)

    let output = model(batchedInput, positionIds: nil, tokenTypeIds: nil, attentionMask: attentionMask)

    let embedding = output.textEmbeds[0]
    eval(embedding)

    return embedding
}

// MARK: - Main Command

@main
struct RecipeSearch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recipe-search",
        abstract: "Semantic search through 50k recipes using MLX embeddings"
    )

    @Option(name: .shortAndLong, help: "Path to recipes JSON file")
    var recipes: String = "../allrecipes-archive/allrecipes.com_database_12042020000000.json"

    @Option(name: .shortAndLong, help: "Path to embeddings binary file")
    var embeddings: String = "../recipe_embeddings.bin"

    @Option(name: .shortAndLong, help: "Embedding model ID")
    var model: String = "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ"

    @Option(name: .shortAndLong, help: "Number of results to return")
    var topK: Int = 5

    mutating func run() async throws {
        print("Loading recipes...")
        let recipesURL = URL(fileURLWithPath: recipes)
        let recipesData = try Data(contentsOf: recipesURL)
        let allRecipes = try JSONDecoder().decode([Recipe].self, from: recipesData)
        print("Loaded \(allRecipes.count) recipes")

        print("\nLoading embeddings...")
        let embeddingsURL = URL(fileURLWithPath: embeddings)
        let embeddingsData = try Data(contentsOf: embeddingsURL)

        // Parse binary format: [count: Int32, dim: Int32, data: [Float32]...]
        var offset = 0
        let count = embeddingsData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
        offset += 4
        let dim = embeddingsData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
        offset += 4

        print("Embeddings: \(count) x \(dim)")

        // Load embeddings directly into MLXArray for GPU-accelerated search
        let embeddingsMatrix: MLXArray = embeddingsData.withUnsafeBytes { ptr in
            let floatPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Float.self)
            let buffer = UnsafeBufferPointer(start: floatPtr, count: Int(count) * Int(dim))
            return MLXArray(Array(buffer)).reshaped([Int(count), Int(dim)])
        }
        eval(embeddingsMatrix)
        print("Loaded embeddings to GPU")

        print("\nLoading embedding model...")
        let container = try await loadModelContainer(
            configuration: ModelConfiguration(id: model)
        )
        print("Model loaded!")

        print("\n" + String(repeating: "=", count: 60))
        print("Recipe Semantic Search")
        print("Type a query to search, or 'quit' to exit")
        print(String(repeating: "=", count: 60))

        while true {
            print("\n> ", terminator: "")
            guard let query = readLine()?.trimmingCharacters(in: .whitespaces) else { break }

            if query.lowercased() == "quit" || query.lowercased() == "exit" || query.lowercased() == "q" {
                break
            }

            if query.isEmpty { continue }

            // Generate query embedding
            let queryEmbeddingArray = await container.perform { model, tokenizer in
                generateEmbedding(text: query, model: model, tokenizer: tokenizer).asArray(Float.self)
            }
            let queryEmbedding = MLXArray(queryEmbeddingArray)

            // Search (GPU-accelerated)
            let results = searchTopK(query: queryEmbedding, embeddingsMatrix: embeddingsMatrix, k: topK)

            print("\nSearch: \"\(query)\"")
            print(String(repeating: "-", count: 60))

            for (rank, result) in results.enumerated() {
                let recipe = allRecipes[result.index]
                let score = result.similarity

                print("\n\(rank + 1). [\(String(format: "%.3f", score))] \(recipe.title)")
                print("   ID: \(recipe.id)")

                if let desc = recipe.description, !desc.isEmpty {
                    let truncated = desc.count > 150 ? String(desc.prefix(150)) + "..." : desc
                    print("   \(truncated)")
                }

                if let rating = recipe.rating, let ratingVal = Double(rating) {
                    print("   Rating: \(String(format: "%.1f", ratingVal))")
                }
            }
        }

        print("\nGoodbye!")
    }
}
