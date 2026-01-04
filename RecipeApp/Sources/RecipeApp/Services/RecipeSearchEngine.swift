import Foundation
import Combine
import MLX
import MLXFast
import MLXNN
import MLXLinalg
import Tokenizers
import Hub

@MainActor
final class RecipeSearchEngine: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = true
    @Published var loadingStatus = "Initializing..."
    @Published var errorMessage: String?

    private var recipes: [Recipe] = []
    private var embeddingsMatrix: MLXArray?
    private var modelContainer: ModelContainer?

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let resultCount = 20

    init() {
        print("[RecipeSearchEngine] Initializing...")
        // Debounce search input for live updating
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                print("[RecipeSearchEngine] Query changed: '\(query)'")
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    func loadData() async {
        print("[RecipeSearchEngine] loadData() called")
        do {
            // Load recipes
            loadingStatus = "Loading recipes..."
            print("[RecipeSearchEngine] \(loadingStatus)")
            let recipesURL = ProjectPaths.recipesJSON
            let recipesData = try Data(contentsOf: recipesURL)
            recipes = try JSONDecoder().decode([Recipe].self, from: recipesData)
            loadingStatus = "Loaded \(recipes.count) recipes"

            // Load embeddings
            loadingStatus = "Loading embeddings..."
            let embeddingsURL = ProjectPaths.embeddingsBin
            let embeddingsData = try Data(contentsOf: embeddingsURL)

            var offset = 0
            let count = embeddingsData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
            offset += 4
            let dim = embeddingsData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
            offset += 4

            embeddingsMatrix = embeddingsData.withUnsafeBytes { ptr in
                let floatPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Float.self)
                let buffer = UnsafeBufferPointer(start: floatPtr, count: Int(count) * Int(dim))
                return MLXArray(Array(buffer)).reshaped([Int(count), Int(dim)])
            }
            eval(embeddingsMatrix!)
            loadingStatus = "Loaded embeddings (\(count) x \(dim))"

            // Load model
            loadingStatus = "Loading embedding model..."
            let config = ModelConfiguration(id: "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ")
            modelContainer = try await loadModelContainer(configuration: config)

            loadingStatus = "Ready"
            isLoading = false

        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        guard let embeddingsMatrix, let modelContainer else { return }

        searchTask = Task {
            // Generate query embedding
            let queryEmbeddingArray = await modelContainer.perform { model, tokenizer in
                Self.generateEmbedding(text: query, model: model, tokenizer: tokenizer)
            }

            if Task.isCancelled { return }

            let queryEmbedding = MLXArray(queryEmbeddingArray)

            // GPU-accelerated search
            let results = Self.searchTopK(
                query: queryEmbedding,
                embeddingsMatrix: embeddingsMatrix,
                k: resultCount
            )

            if Task.isCancelled { return }

            // Map to SearchResult
            let recipesCopy = self.recipes
            let newResults = results.compactMap { result -> SearchResult? in
                guard result.index < recipesCopy.count else { return nil }
                return SearchResult(
                    recipe: recipesCopy[result.index],
                    similarity: result.similarity
                )
            }
            self.searchResults = newResults
        }
    }

    private nonisolated static func generateEmbedding(text: String, model: EmbeddingModel, tokenizer: Tokenizer) -> [Float] {
        // Use instruction prefix for better retrieval quality with Qwen3
        let queryWithInstruction = "Instruct: Find recipes matching this description\nQuery: \(text)"
        var encoded = tokenizer.encode(text: queryWithInstruction, addSpecialTokens: true)

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

        return embedding.asArray(Float.self)
    }

    private nonisolated static func searchTopK(query: MLXArray, embeddingsMatrix: MLXArray, k: Int) -> [(index: Int, similarity: Float)] {
        let queryNorm = sqrt(sum(query * query))
        let normalizedQuery = query / queryNorm

        let similarities = matmul(normalizedQuery.reshaped([1, -1]), embeddingsMatrix.T).squeezed()

        let topIndices = argSort(similarities)[(-k)...]
        eval(topIndices)

        let indicesArray = topIndices.asArray(Int32.self).reversed()
        let simArray = similarities.asArray(Float.self)

        return indicesArray.map { idx in
            (index: Int(idx), similarity: simArray[Int(idx)])
        }
    }
}
