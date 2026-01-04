import Foundation
import Hub
import MLX
import MLXNN
import MLXRandom
import Tokenizers

func prepareModelDirectory(
    hub: HubApi, configuration: ModelConfiguration,
    progressHandler: @Sendable @escaping (Progress) -> Void
) async throws -> URL {
    do {
        switch configuration.id {
        case .id(let id):
            let repo = Hub.Repo(id: id)
            let modelFiles = ["*.safetensors", "config.json"]
            return try await hub.snapshot(
                from: repo, matching: modelFiles, progressHandler: progressHandler)

        case .directory(let directory):
            return directory
        }
    } catch Hub.HubClientError.authorizationRequired {
        return configuration.modelDirectory(hub: hub)
    } catch {
        let nserror = error as NSError
        if nserror.domain == NSURLErrorDomain && nserror.code == NSURLErrorNotConnectedToInternet {
            return configuration.modelDirectory(hub: hub)
        } else {
            throw error
        }
    }
}

public func load(
    hub: HubApi = HubApi(), configuration: ModelConfiguration,
    progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
) async throws -> (EmbeddingModel, Tokenizer) {
    let modelDirectory = try await prepareModelDirectory(
        hub: hub, configuration: configuration, progressHandler: progressHandler)
    let model = try loadSynchronous(modelDirectory: modelDirectory)
    let tokenizer = try await loadTokenizer(configuration: configuration, hub: hub)

    return (model, tokenizer)
}

func loadSynchronous(modelDirectory: URL) throws -> EmbeddingModel {
    let configurationURL = modelDirectory.appending(component: "config.json")
    let baseConfig = try JSONDecoder().decode(
        BaseConfiguration.self, from: Data(contentsOf: configurationURL))

    let model = try baseConfig.modelType.createModel(configuration: configurationURL)

    var weights = [String: MLXArray]()
    let enumerator = FileManager.default.enumerator(
        at: modelDirectory, includingPropertiesForKeys: nil)!
    for case let url as URL in enumerator {
        if url.pathExtension == "safetensors" {
            let w = try loadArrays(url: url)
            for (key, value) in w {
                weights[key] = value
            }
        }
    }

    weights = model.sanitize(weights: weights)

    if let quantization = baseConfig.quantization {
        quantize(model: model, groupSize: quantization.groupSize, bits: quantization.bits) {
            path, module in
            weights["\(path).scales"] != nil
        }
    }

    let parameters = ModuleParameters.unflattened(weights)
    try model.update(parameters: parameters, verify: [.all])

    eval(model)

    return model
}

public func loadModelContainer(
    hub: HubApi = HubApi(), configuration: ModelConfiguration,
    progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
) async throws -> ModelContainer {
    switch configuration.id {
    case .directory(let directory):
        // Direct loading from bundled directory - no network required
        return try await ModelContainer(modelDirectory: directory)
    case .id:
        // Network-based loading via HuggingFace Hub
        let modelDirectory = try await prepareModelDirectory(
            hub: hub, configuration: configuration, progressHandler: progressHandler)
        return try await ModelContainer(
            hub: hub, modelDirectory: modelDirectory, configuration: configuration)
    }
}

public func loadTokenizer(configuration: ModelConfiguration, hub: HubApi) async throws -> Tokenizer {
    let (tokenizerConfig, tokenizerData) = try await loadTokenizerConfig(
        configuration: configuration, hub: hub)

    return try PreTrainedTokenizer(
        tokenizerConfig: tokenizerConfig, tokenizerData: tokenizerData)
}

/// Load tokenizer directly from a local directory without network access
func loadTokenizerFromDirectory(modelDirectory: URL) throws -> Tokenizer {
    let tokenizerConfigURL = modelDirectory.appendingPathComponent("tokenizer_config.json")
    let tokenizerDataURL = modelDirectory.appendingPathComponent("tokenizer.json")

    let tokenizerConfigData = try Data(contentsOf: tokenizerConfigURL)
    let tokenizerData = try Data(contentsOf: tokenizerDataURL)

    // Decode JSON to dictionary, then create Config
    guard let configDict = try JSONSerialization.jsonObject(with: tokenizerConfigData) as? [NSString: Any],
          let dataDict = try JSONSerialization.jsonObject(with: tokenizerData) as? [NSString: Any] else {
        throw EmbedderError(message: "Failed to parse tokenizer JSON files")
    }

    let tokenizerConfig = Config(configDict)
    let tokenizerDataConfig = Config(dataDict)

    return try PreTrainedTokenizer(
        tokenizerConfig: tokenizerConfig, tokenizerData: tokenizerDataConfig)
}

func loadTokenizerConfig(configuration: ModelConfiguration, hub: HubApi) async throws -> (Config, Config) {
    let config: LanguageModelConfigurationFromHub

    switch configuration.id {
    case .id(let id):
        do {
            let loaded = LanguageModelConfigurationFromHub(
                modelName: configuration.tokenizerId ?? id, hubApi: hub)
            _ = try await loaded.tokenizerConfig
            config = loaded
        } catch {
            let nserror = error as NSError
            if nserror.domain == NSURLErrorDomain && nserror.code == NSURLErrorNotConnectedToInternet {
                config = LanguageModelConfigurationFromHub(
                    modelFolder: configuration.modelDirectory(hub: hub), hubApi: hub)
            } else {
                throw error
            }
        }
    case .directory(let directory):
        config = LanguageModelConfigurationFromHub(modelFolder: directory, hubApi: hub)
    }

    guard let tokenizerConfig = try await config.tokenizerConfig else {
        throw EmbedderError(message: "missing config")
    }
    let tokenizerData = try await config.tokenizerData
    return (tokenizerConfig, tokenizerData)
}
