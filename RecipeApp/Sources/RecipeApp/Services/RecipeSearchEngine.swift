import Foundation
import Combine
import MLX
import MLXFast
import MLXNN
import MLXLinalg
import Tokenizers
import Hub

enum SearchMode: Equatable {
    case semantic
    case text
}

@MainActor
final class RecipeSearchEngine: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = true
    @Published var loadingStatus = "Initializing..."
    @Published var errorMessage: String?
    @Published var searchMode: SearchMode = .semantic
    @Published var hasMoreResults = false
    @Published var totalResultCount = 0
    @Published var isSearching = false

    private var recipes: [Recipe] = []
    private var embeddingsMatrix: MLXArray?
    private var modelContainer: ModelContainer?

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var searchGeneration = 0  // Track search generation to prevent stale results

    private let pageSize = 20
    private var currentPage = 0
    private var allSemanticResults: [(index: Int, similarity: Float)] = []
    private var allTextResults: [Int] = []

    init() {
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.currentPage = 0
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    func loadData() async {
        do {
            loadingStatus = "Loading recipes..."
            let recipesURL = ProjectPaths.recipesJSON
            let recipesData = try Data(contentsOf: recipesURL)
            recipes = try JSONDecoder().decode([Recipe].self, from: recipesData)
            loadingStatus = "Loaded \(recipes.count) recipes"

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

            loadingStatus = "Loading embedding model..."
            let config = ModelConfiguration.preferBundled()
            modelContainer = try await loadModelContainer(configuration: config)

            loadingStatus = "Ready"
            isLoading = false

        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func setSearchMode(_ mode: SearchMode) {
        guard mode != searchMode else { return }
        searchMode = mode
        currentPage = 0
        performSearch(query: searchQuery)
    }

    func loadMore() {
        currentPage += 1
        updateDisplayedResults()
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        searchGeneration += 1
        let currentGeneration = searchGeneration

        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            allSemanticResults = []
            allTextResults = []
            hasMoreResults = false
            totalResultCount = 0
            isSearching = false
            return
        }

        isSearching = true

        if searchMode == .semantic {
            performSemanticSearch(query: trimmedQuery, generation: currentGeneration)
        } else {
            performTextSearch(query: trimmedQuery, generation: currentGeneration)
        }
    }

    private func performSemanticSearch(query: String, generation: Int) {
        guard let embeddingsMatrix, let modelContainer else {
            isSearching = false
            return
        }

        searchTask = Task {
            let queryEmbeddingArray = await modelContainer.perform { model, tokenizer in
                Self.generateEmbedding(text: query, model: model, tokenizer: tokenizer)
            }

            // Check if this search is still current
            if Task.isCancelled || generation != searchGeneration { return }

            let queryEmbedding = MLXArray(queryEmbeddingArray)

            // Get all results sorted by similarity
            let results = Self.searchAll(
                query: queryEmbedding,
                embeddingsMatrix: embeddingsMatrix
            )

            // Check again after heavy computation
            if Task.isCancelled || generation != searchGeneration { return }

            allSemanticResults = results
            totalResultCount = allSemanticResults.count
            updateDisplayedResults()
            isSearching = false
        }
    }

    private func performTextSearch(query: String, generation: Int) {
        let recipes = self.recipes  // Capture for async use

        searchTask = Task.detached(priority: .userInitiated) {
            let queryLower = query.lowercased()
            let queryWords = queryLower.split(separator: " ").map(String.init)

            // Score each recipe by text match
            var scored: [(index: Int, score: Int)] = []

            for (index, recipe) in recipes.enumerated() {
                var score = 0

                let titleLower = recipe.title.lowercased()
                let descLower = (recipe.description ?? "").lowercased()
                let ingredientsLower = (recipe.ingredients ?? []).joined(separator: " ").lowercased()

                for word in queryWords {
                    // Title matches are weighted higher
                    if titleLower.contains(word) {
                        score += 10
                    }
                    if descLower.contains(word) {
                        score += 3
                    }
                    if ingredientsLower.contains(word) {
                        score += 2
                    }
                }

                // Exact phrase match bonus
                if titleLower.contains(queryLower) {
                    score += 20
                }

                if score > 0 {
                    scored.append((index: index, score: score))
                }
            }

            // Sort by score descending
            scored.sort { $0.score > $1.score }
            let resultIndices = scored.map { $0.index }

            // Update UI on main actor
            await MainActor.run {
                // Check if this search is still current
                guard generation == self.searchGeneration else { return }

                self.allTextResults = resultIndices
                self.totalResultCount = self.allTextResults.count
                self.updateDisplayedResults()
                self.isSearching = false
            }
        }
    }

    private func updateDisplayedResults() {
        let startIndex = 0
        let endIndex = min((currentPage + 1) * pageSize, totalResultCount)

        if searchMode == .semantic {
            let resultsSlice = Array(allSemanticResults.prefix(endIndex))
            searchResults = resultsSlice.compactMap { result -> SearchResult? in
                guard result.index < recipes.count else { return nil }
                return SearchResult(
                    recipe: recipes[result.index],
                    similarity: result.similarity
                )
            }
        } else {
            let indicesSlice = Array(allTextResults.prefix(endIndex))
            searchResults = indicesSlice.compactMap { index -> SearchResult? in
                guard index < recipes.count else { return nil }
                return SearchResult(
                    recipe: recipes[index],
                    similarity: 1.0  // Text search doesn't have similarity scores
                )
            }
        }

        hasMoreResults = endIndex < totalResultCount
    }

    private nonisolated static func generateEmbedding(text: String, model: EmbeddingModel, tokenizer: Tokenizer) -> [Float] {
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

    private nonisolated static func searchAll(query: MLXArray, embeddingsMatrix: MLXArray) -> [(index: Int, similarity: Float)] {
        let queryNorm = sqrt(sum(query * query))
        let normalizedQuery = query / queryNorm

        let similarities = matmul(normalizedQuery.reshaped([1, -1]), embeddingsMatrix.T).squeezed()

        // Sort all by similarity
        let sortedIndices = argSort(similarities)
        eval(sortedIndices)

        let indicesArray = sortedIndices.asArray(Int32.self).reversed()
        let simArray = similarities.asArray(Float.self)

        return indicesArray.map { idx in
            (index: Int(idx), similarity: simArray[Int(idx)])
        }
    }
}
