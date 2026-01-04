import Foundation
import Hub

public enum StringOrNumber: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case float(Float)
    case ints([Int])
    case floats([Float])

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()

        if let v = try? values.decode(Int.self) {
            self = .int(v)
        } else if let v = try? values.decode(Float.self) {
            self = .float(v)
        } else if let v = try? values.decode([Int].self) {
            self = .ints(v)
        } else if let v = try? values.decode([Float].self) {
            self = .floats(v)
        } else {
            let v = try values.decode(String.self)
            self = .string(v)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .float(let v): try container.encode(v)
        case .ints(let v): try container.encode(v)
        case .floats(let v): try container.encode(v)
        }
    }

    public func asFloat() -> Float? {
        switch self {
        case .string: nil
        case .int(let v): Float(v)
        case .float(let float): float
        case .ints(let array): array.count == 1 ? Float(array[0]) : nil
        case .floats(let array): array.count == 1 ? array[0] : nil
        }
    }
}

struct EmbedderError: Error {
    let message: String
}

public struct ModelType: RawRepresentable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public func createModel(configuration: URL) throws -> EmbeddingModel {
        switch rawValue {
        case "qwen3":
            let config = try JSONDecoder().decode(
                Qwen3Configuration.self, from: Data(contentsOf: configuration))
            return Qwen3Model(config)
        default:
            throw EmbedderError(message: "Unsupported model type: \(rawValue)")
        }
    }
}

public struct BaseConfiguration: Codable, Sendable {
    public let modelType: ModelType

    public struct Quantization: Codable, Sendable {
        let groupSize: Int
        let bits: Int

        enum CodingKeys: String, CodingKey {
            case groupSize = "group_size"
            case bits = "bits"
        }
    }

    public var quantization: Quantization?

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case quantization
    }
}

public struct ModelConfiguration: Sendable {
    public enum Identifier: Sendable {
        case id(String)
        case directory(URL)
    }

    public var id: Identifier

    public var name: String {
        switch id {
        case .id(let string): string
        case .directory(let url):
            url.deletingLastPathComponent().lastPathComponent + "/" + url.lastPathComponent
        }
    }

    public let tokenizerId: String?
    public let overrideTokenizer: String?

    public init(id: String, tokenizerId: String? = nil, overrideTokenizer: String? = nil) {
        self.id = .id(id)
        self.tokenizerId = tokenizerId
        self.overrideTokenizer = overrideTokenizer
    }

    public init(directory: URL, tokenizerId: String? = nil, overrideTokenizer: String? = nil) {
        self.id = .directory(directory)
        self.tokenizerId = tokenizerId
        self.overrideTokenizer = overrideTokenizer
    }

    public func modelDirectory(hub: HubApi = HubApi()) -> URL {
        switch id {
        case .id(let id):
            let repo = Hub.Repo(id: id)
            return hub.localRepoLocation(repo)
        case .directory(let directory):
            return directory
        }
    }

    /// Creates a configuration for the bundled model (if available)
    public static func bundled() -> ModelConfiguration? {
        guard let modelDir = ProjectPaths.modelDirectory else {
            return nil
        }
        return ModelConfiguration(directory: modelDir)
    }

    /// Creates configuration, preferring bundled model over HuggingFace download
    public static func preferBundled(
        fallbackId: String = "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ"
    ) -> ModelConfiguration {
        if let bundled = Self.bundled() {
            return bundled
        }
        return ModelConfiguration(id: fallbackId)
    }
}
