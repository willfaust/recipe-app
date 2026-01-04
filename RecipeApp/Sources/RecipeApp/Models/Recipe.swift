import Foundation

struct RecipeStep: Codable, Hashable, Sendable {
    let step: Int
    let instruction: String
}

extension String {
    /// Cleans up HTML entities in recipe text
    var cleanedHTML: String {
        self.replacingOccurrences(of: "&#174;", with: "®")
            .replacingOccurrences(of: "&#169;", with: "©")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\r\\n", with: " ")
            .replacingOccurrences(of: "\\r", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")
    }
}

struct NutritionInfo: Codable, Hashable, Sendable {
    let calories: String?
    let servings: String?
    let totalFat: String?
    let saturatedFat: String?
    let cholesterol: String?
    let sodium: String?
    let potassium: String?
    let totalCarbohydrate: String?
    let dietryFibre: String?
    let protein: String?
    let sugars: String?
    let vitaminA: String?
    let vitaminC: String?
    let calcium: String?
    let iron: String?

    enum CodingKeys: String, CodingKey {
        case calories, servings, cholesterol, sodium, potassium, protein, sugars, calcium, iron
        case totalFat = "total_fat"
        case saturatedFat = "saturated_fat"
        case totalCarbohydrate = "total_carbohydrate"
        case dietryFibre = "dietry_fibre"
        case vitaminA = "vitamin_a"
        case vitaminC = "vitamin_c"
    }
}

struct Recipe: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]?
    let steps: [RecipeStep]?
    let rating: String?
    let images: [String]?
    let nutritionalInformation: NutritionInfo?
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, ingredients, steps, rating, images
        case nutritionalInformation = "nutritional_information"
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case totalTime = "total_time"
    }

    var ratingValue: Double? {
        guard let rating else { return nil }
        return Double(rating)
    }

    var thumbnailURL: URL? {
        guard let images, let first = images.first else { return nil }
        return ProjectPaths.imageURL(for: first)
    }

    var displayDescription: String {
        guard let description, !description.isEmpty else {
            return "No description available"
        }
        return description.cleanedHTML
    }

    var displayPrepTime: String? {
        prepTime.flatMap { parseISO8601Duration($0) }
    }

    var displayCookTime: String? {
        cookTime.flatMap { parseISO8601Duration($0) }
    }

    var displayTotalTime: String? {
        totalTime.flatMap { parseISO8601Duration($0) }
    }

    private func parseISO8601Duration(_ duration: String) -> String? {
        // Parse ISO 8601 duration format: PT1H30M, PT45M, PT2H, etc.
        guard duration.hasPrefix("PT") else {
            // Already in readable format
            return duration.isEmpty ? nil : duration
        }

        var remaining = duration.dropFirst(2) // Remove "PT"
        var hours = 0
        var minutes = 0

        // Extract hours
        if let hIndex = remaining.firstIndex(of: "H") {
            if let h = Int(remaining[..<hIndex]) {
                hours = h
            }
            remaining = remaining[remaining.index(after: hIndex)...]
        }

        // Extract minutes
        if let mIndex = remaining.firstIndex(of: "M") {
            if let m = Int(remaining[..<mIndex]) {
                minutes = m
            }
        }

        // Format output
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        }
        return nil
    }
}

struct SearchResult: Identifiable, Hashable {
    let id: String
    let recipe: Recipe
    let similarity: Float

    init(recipe: Recipe, similarity: Float) {
        self.id = recipe.id
        self.recipe = recipe
        self.similarity = similarity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}
