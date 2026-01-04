import SwiftUI

struct NutritionLabelView: View {
    let nutrition: NutritionInfo
    @Environment(\.colorScheme) var colorScheme

    private var labelBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(white: 0.4) : Color.black
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(white: 0.6) : Color.gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Nutrition Facts")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(textColor)
                .padding(.bottom, 2)

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(borderColor)

            if let servings = nutrition.servings, servings != "0" {
                Text("\(servings) servings per container")
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .padding(.vertical, 4)
            }

            Rectangle()
                .frame(height: 8)
                .foregroundStyle(textColor)
                .padding(.vertical, 2)

            // Calories
            HStack {
                Text("Calories")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textColor)
                Spacer()
                Text(nutrition.calories ?? "0")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(textColor)
            }
            .padding(.vertical, 4)

            thickDivider

            // Daily Value header
            HStack {
                Spacer()
                Text("% Daily Value*")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(textColor)
            }
            .padding(.vertical, 2)

            thinDivider

            // Main nutrients
            nutrientRow("Total Fat", value: nutrition.totalFat, unit: "g", bold: true)
            thinDivider
            nutrientRow("  Saturated Fat", value: nutrition.saturatedFat, unit: "g", bold: false)
            thinDivider
            nutrientRow("Cholesterol", value: nutrition.cholesterol, unit: "mg", bold: true)
            thinDivider
            nutrientRow("Sodium", value: nutrition.sodium, unit: "mg", bold: true)
            thinDivider
            nutrientRow("Potassium", value: nutrition.potassium, unit: "mg", bold: true)
            thinDivider
            nutrientRow("Total Carbohydrate", value: nutrition.totalCarbohydrate, unit: "g", bold: true)
            thinDivider
            nutrientRow("  Dietary Fiber", value: nutrition.dietryFibre, unit: "g", bold: false)
            thinDivider
            nutrientRow("  Sugars", value: nutrition.sugars, unit: "g", bold: false)
            thinDivider
            nutrientRow("Protein", value: nutrition.protein, unit: "g", bold: true)

            thickDivider

            // Vitamins and minerals
            vitaminRow("Vitamin A", value: nutrition.vitaminA)
            thinDivider
            vitaminRow("Vitamin C", value: nutrition.vitaminC)
            thinDivider
            vitaminRow("Calcium", value: nutrition.calcium)
            thinDivider
            vitaminRow("Iron", value: nutrition.iron)

            thinDivider

            // Footnote
            Text("* Percent Daily Values are based on a 2,000 calorie diet.")
                .font(.system(size: 9))
                .foregroundStyle(secondaryTextColor)
                .padding(.top, 4)
        }
        .padding(12)
        .background(labelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 2)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, y: 4)
        .frame(maxWidth: 280)
    }

    private var thinDivider: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundStyle(secondaryTextColor.opacity(0.5))
    }

    private var thickDivider: some View {
        Rectangle()
            .frame(height: 4)
            .foregroundStyle(textColor)
            .padding(.vertical, 2)
    }

    private func nutrientRow(_ name: String, value: String?, unit: String, bold: Bool) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12, weight: bold ? .bold : .regular))
                .foregroundStyle(textColor)
            Text(formatNutrientValue(value, unit: unit))
                .font(.system(size: 12))
                .foregroundStyle(textColor)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func vitaminRow(_ name: String, value: String?) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(textColor)
            Spacer()
            Text(formatVitaminValue(value))
                .font(.system(size: 12))
                .foregroundStyle(textColor)
        }
        .padding(.vertical, 2)
    }

    /// Formats nutrient value, avoiding duplicate units
    private func formatNutrientValue(_ value: String?, unit: String) -> String {
        guard let value = value, !value.isEmpty else { return "0\(unit)" }
        // Check if value already contains a unit (g, mg, etc.)
        let hasUnit = value.contains("g") || value.contains("mg") || value.contains("mcg")
        if hasUnit {
            return value
        }
        return "\(value)\(unit)"
    }

    /// Formats vitamin/mineral value as percentage
    private func formatVitaminValue(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "0%" }
        // Extract just the numeric part if it contains units like IU, mg, mcg
        let numericValue = value
            .replacingOccurrences(of: "IU", with: "")
            .replacingOccurrences(of: "mcg", with: "")
            .replacingOccurrences(of: "mg", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        // If already ends with %, don't add another
        if value.hasSuffix("%") {
            return value
        }
        return "\(numericValue)%"
    }
}

#Preview {
    NutritionLabelView(nutrition: NutritionInfo(
        calories: "250",
        servings: "4",
        totalFat: "12",
        saturatedFat: "3",
        cholesterol: "30",
        sodium: "470",
        potassium: "350",
        totalCarbohydrate: "31",
        dietryFibre: "4",
        protein: "5",
        sugars: "5",
        vitaminA: "4",
        vitaminC: "2",
        calcium: "20",
        iron: "4"
    ))
    .padding()
}
