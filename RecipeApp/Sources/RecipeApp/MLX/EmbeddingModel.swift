import Foundation
import Hub
import MLX
import MLXNN
import Tokenizers
import MLXLinalg

public actor ModelContainer {
    let model: EmbeddingModel
    let tokenizer: Tokenizer

    public init(model: EmbeddingModel, tokenizer: Tokenizer) {
        self.model = model
        self.tokenizer = tokenizer
    }

    public init(hub: HubApi, modelDirectory: URL, configuration: ModelConfiguration) async throws {
        self.model = try loadSynchronous(modelDirectory: modelDirectory)
        let (tokenizerConfig, tokenizerData) = try await loadTokenizerConfig(
            configuration: configuration, hub: hub)
        self.tokenizer = try PreTrainedTokenizer(
            tokenizerConfig: tokenizerConfig, tokenizerData: tokenizerData)
    }

    /// Initialize from a local directory without network access (for bundled apps)
    public init(modelDirectory: URL) async throws {
        self.model = try loadSynchronous(modelDirectory: modelDirectory)
        self.tokenizer = try loadTokenizerFromDirectory(modelDirectory: modelDirectory)
    }

    public func perform<R>(_ action: @Sendable (EmbeddingModel, Tokenizer) throws -> R) rethrows -> R {
        try action(model, tokenizer)
    }
}

public struct EmbeddingModelOutput {
    public let hiddenStates: MLXArray?
    public let poolerOutput: MLXArray?
    public let textEmbeds: MLXArray

    public init(hiddenStates: MLXArray?, poolerOutput: MLXArray?, textEmbeds: MLXArray) {
        self.hiddenStates = hiddenStates
        self.poolerOutput = poolerOutput
        self.textEmbeds = textEmbeds
    }
}

public protocol EmbeddingModel: Module {
    func callAsFunction(
        _ inputs: MLXArray, positionIds: MLXArray?, tokenTypeIds: MLXArray?,
        attentionMask: MLXArray?
    ) -> EmbeddingModelOutput

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray]
}

extension EmbeddingModel {
    public func callAsFunction(
        _ inputs: MLXArray, positionIds: MLXArray? = nil, tokenTypeIds: MLXArray? = nil,
        attentionMask: MLXArray? = nil
    ) -> EmbeddingModelOutput {
        return callAsFunction(
            inputs, positionIds: positionIds, tokenTypeIds: tokenTypeIds,
            attentionMask: attentionMask)
    }
}
