import Foundation

struct RecipeStep: Codable, Hashable, Sendable {
    let step: Int
    let instruction: String
}

extension String {
    /// Cleans up HTML entities in recipe text
    var cleanedHTML: String {
        var result = self
            // Common HTML entities
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            // Special characters
            .replacingOccurrences(of: "&#174;", with: "®")
            .replacingOccurrences(of: "&reg;", with: "®")
            .replacingOccurrences(of: "&#169;", with: "©")
            .replacingOccurrences(of: "&copy;", with: "©")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "'")
            .replacingOccurrences(of: "&#8220;", with: "\"")
            .replacingOccurrences(of: "&#8221;", with: "\"")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#xA0;", with: " ")
            // Fractions
            .replacingOccurrences(of: "&#189;", with: "½")
            .replacingOccurrences(of: "&frac12;", with: "½")
            .replacingOccurrences(of: "&#188;", with: "¼")
            .replacingOccurrences(of: "&frac14;", with: "¼")
            .replacingOccurrences(of: "&#190;", with: "¾")
            .replacingOccurrences(of: "&frac34;", with: "¾")
            .replacingOccurrences(of: "&#8531;", with: "⅓")
            .replacingOccurrences(of: "&#8532;", with: "⅔")
            // Degree symbol
            .replacingOccurrences(of: "&#176;", with: "°")
            .replacingOccurrences(of: "&deg;", with: "°")
            // Escaped newlines
            .replacingOccurrences(of: "\\r\\n", with: " ")
            .replacingOccurrences(of: "\\r", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")

        // Remove HTML tags
        while let range = result.range(of: "<[^>]+>", options: .regularExpression) {
            result.removeSubrange(range)
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}

struct NutritionInfo: Codable, Hashable, Sendable {
    let calories: String?
    let totalFat: String?
    let saturatedFat: String?
    let unsaturatedFat: String?
    let transFat: String?
    let cholesterol: String?
    let sodium: String?
    let totalCarbohydrate: String?
    let fiber: String?
    let sugar: String?
    let protein: String?

    enum CodingKeys: String, CodingKey {
        case calories, cholesterol, sodium, fiber, sugar, protein
        case totalFat = "total_fat"
        case saturatedFat = "saturated_fat"
        case unsaturatedFat = "unsaturated_fat"
        case transFat = "trans_fat"
        case totalCarbohydrate = "total_carbohydrate"
    }

    /// Formats a nutrition value, converting "grams" to "g" and "milligrams" to "mg"
    static func formatValue(_ value: String?, defaultUnit: String = "") -> String {
        guard let value = value, !value.isEmpty else { return "0\(defaultUnit)" }
        // Important: replace milligrams BEFORE grams (since "milligrams" contains "grams")
        return value
            .replacingOccurrences(of: " milligrams", with: "mg")
            .replacingOccurrences(of: " milligram", with: "mg")
            .replacingOccurrences(of: "milligrams", with: "mg")
            .replacingOccurrences(of: "milligram", with: "mg")
            .replacingOccurrences(of: " grams", with: "g")
            .replacingOccurrences(of: " gram", with: "g")
            .replacingOccurrences(of: "grams", with: "g")
            .replacingOccurrences(of: "gram", with: "g")
    }
}

struct Recipe: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]?
    let steps: [RecipeStep]?
    let rating: String?
    let ratingCount: String?
    let images: [String]?
    let nutritionalInformation: NutritionInfo?
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, ingredients, steps, rating, images
        case ratingCount = "rating_count"
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

    /// Returns true if the image is a generic placeholder that shouldn't be shown in detail view
    var hasGenericPlaceholder: Bool {
        guard let images, let first = images.first else { return true }
        let basename = first.replacingOccurrences(of: ".webp", with: "")
        guard basename.hasPrefix("placeholder_"),
              let numStr = basename.split(separator: "_").last,
              let num = Int(numStr) else { return false }
        // Hide placeholders 1-17, 20, 23-25
        return (1...17).contains(num) || num == 20 || (23...25).contains(num)
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
        // Handle empty or zero values
        guard !duration.isEmpty else { return nil }

        // Handle plain number format (minutes only, like "15" or "0")
        if let mins = Int(duration) {
            if mins <= 0 { return nil }
            if mins >= 60 {
                let hours = mins / 60
                let remaining = mins % 60
                if remaining > 0 {
                    return "\(hours)h \(remaining)m"
                }
                return "\(hours)h"
            }
            return "\(mins)m"
        }

        // Parse ISO 8601 duration format: PT1H30M, PT45M, PT2H, etc.
        guard duration.hasPrefix("PT") else {
            // Already in readable format
            return duration
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
