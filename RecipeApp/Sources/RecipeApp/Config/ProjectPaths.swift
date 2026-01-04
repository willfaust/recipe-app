import Foundation

/// Resolves paths to project data files.
/// Uses RECIPE_PROJECT_ROOT environment variable if set, otherwise auto-detects
/// by walking up from the executable location to find the project root.
enum ProjectPaths {
    /// Root directory of the recipe-project
    static let projectRoot: URL = {
        // Check environment variable first
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
        projectRoot
            .appendingPathComponent("allrecipes-archive")
            .appendingPathComponent("allrecipes.com_database_12042020000000.json")
    }

    /// Path to the embeddings binary file
    static var embeddingsBin: URL {
        projectRoot.appendingPathComponent("recipe_embeddings.bin")
    }

    /// Path to recipe images directory
    static var imagesDirectory: URL {
        projectRoot
            .appendingPathComponent("allrecipes-archive")
            .appendingPathComponent("images")
            .appendingPathComponent("250x250")
    }

    /// Returns the URL for a recipe image
    static func imageURL(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }
}
