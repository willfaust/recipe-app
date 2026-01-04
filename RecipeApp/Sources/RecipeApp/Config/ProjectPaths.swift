import Foundation

/// Resolves paths to project data files.
/// Supports two modes:
/// 1. Bundled mode: Resources are inside the .app bundle (for distribution)
/// 2. Development mode: Uses RECIPE_PROJECT_ROOT env var or auto-detects project root
enum ProjectPaths {
    /// Determines if running as a bundled app with embedded resources
    private static let isBundled: Bool = {
        if let resourceURL = Bundle.main.resourceURL {
            let dataURL = resourceURL.appendingPathComponent("Data")
            return FileManager.default.fileExists(atPath: dataURL.path)
        }
        return false
    }()

    /// Root directory for resources (bundle Resources/ or project root)
    static let resourceRoot: URL = {
        // Bundled mode: use app bundle's Resources directory
        if isBundled, let resourceURL = Bundle.main.resourceURL {
            return resourceURL
        }

        // Development mode: check environment variable first
        if let envRoot = ProcessInfo.processInfo.environment["RECIPE_PROJECT_ROOT"] {
            return URL(fileURLWithPath: envRoot)
        }

        // Auto-detect: walk up from executable to find project root
        var url = URL(fileURLWithPath: Bundle.main.executablePath ?? FileManager.default.currentDirectoryPath)

        // Walk up looking for allrecipes-archive directory
        for _ in 0..<10 {
            url = url.deletingLastPathComponent()
            let archiveURL = url.appendingPathComponent("allrecipes-archive")
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                return url
            }
        }

        // Fallback to current directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }()

    /// Path to the recipes JSON database
    static var recipesJSON: URL {
        if isBundled {
            return resourceRoot
                .appendingPathComponent("Data")
                .appendingPathComponent("recipes.json")
        }
        return resourceRoot
            .appendingPathComponent("allrecipes-archive")
            .appendingPathComponent("allrecipes.com_database_12042020000000.json")
    }

    /// Path to the embeddings binary file
    static var embeddingsBin: URL {
        if isBundled {
            return resourceRoot
                .appendingPathComponent("Data")
                .appendingPathComponent("embeddings.bin")
        }
        return resourceRoot.appendingPathComponent("recipe_embeddings.bin")
    }

    /// Path to recipe images directory
    static var imagesDirectory: URL {
        if isBundled {
            return resourceRoot
                .appendingPathComponent("Images")
                .appendingPathComponent("250x250")
        }
        return resourceRoot
            .appendingPathComponent("allrecipes-archive")
            .appendingPathComponent("images")
            .appendingPathComponent("250x250")
    }

    /// Path to bundled MLX model directory (nil if not bundled)
    static var modelDirectory: URL? {
        if isBundled {
            let modelDir = resourceRoot.appendingPathComponent("Model")
            if FileManager.default.fileExists(atPath: modelDir.path) {
                return modelDir
            }
        }
        return nil
    }

    /// Returns the URL for a recipe image
    static func imageURL(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }
}
