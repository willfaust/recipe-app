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

            // Main nutrients
            nutrientRow("Total Fat", value: nutrition.totalFat, unit: "g", bold: true)
            thinDivider
            nutrientRow("  Saturated Fat", value: nutrition.saturatedFat, unit: "g", bold: false)
            thinDivider
            nutrientRow("  Unsaturated Fat", value: nutrition.unsaturatedFat, unit: "g", bold: false)
            thinDivider
            nutrientRow("  Trans Fat", value: nutrition.transFat, unit: "g", bold: false)
            thinDivider
            nutrientRow("Cholesterol", value: nutrition.cholesterol, unit: "mg", bold: true)
            thinDivider
            nutrientRow("Sodium", value: nutrition.sodium, unit: "mg", bold: true)
            thinDivider
            nutrientRow("Total Carbohydrate", value: nutrition.totalCarbohydrate, unit: "g", bold: true)
            thinDivider
            nutrientRow("  Dietary Fiber", value: nutrition.fiber, unit: "g", bold: false)
            thinDivider
            nutrientRow("  Sugars", value: nutrition.sugar, unit: "g", bold: false)
            thinDivider
            nutrientRow("Protein", value: nutrition.protein, unit: "g", bold: true)

            thickDivider

            // Vitamins and minerals (N/A for NYTimes data)
            vitaminRow("Vitamin A", value: nil)
            thinDivider
            vitaminRow("Vitamin C", value: nil)
            thinDivider
            vitaminRow("Calcium", value: nil)
            thinDivider
            vitaminRow("Iron", value: nil)

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
            Text(NutritionInfo.formatValue(value, defaultUnit: unit))
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
            Text("N/A")
                .font(.system(size: 12))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NutritionLabelView(nutrition: NutritionInfo(
        calories: "250",
        totalFat: "12 grams",
        saturatedFat: "3 grams",
        unsaturatedFat: "7 grams",
        transFat: "0 grams",
        cholesterol: "30 milligrams",
        sodium: "470 milligrams",
        totalCarbohydrate: "31 grams",
        fiber: "4 grams",
        sugar: "5 grams",
        protein: "5 grams"
    ))
    .padding()
}
