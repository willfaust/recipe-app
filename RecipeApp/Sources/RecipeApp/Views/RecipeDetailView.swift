import SwiftUI

// MARK: - Glass Effect Extension (iOS 26+ with fallback)
extension View {
    @ViewBuilder
    func glassSection(in shape: some Shape = RoundedRectangle(cornerRadius: 16)) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func glassBadge() -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .white.opacity(0.1), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                }
                .glassEffect(.regular, in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                timeSection
                descriptionSection
                stepsSection
                ingredientsAndNutritionSection
            }
            .padding()
        }
        .background {
            backgroundGradient
        }
        .navigationTitle(recipe.title)
        #if os(macOS)
        .navigationSubtitle("Recipe #\(recipe.id)")
        #endif
    }

    @ViewBuilder
    private var ingredientsAndNutritionSection: some View {
        let hasIngredients = recipe.ingredients != nil && !recipe.ingredients!.isEmpty
        let hasNutrition = recipe.nutritionalInformation != nil &&
            recipe.nutritionalInformation!.calories != nil &&
            recipe.nutritionalInformation!.calories != "0"

        if hasIngredients || hasNutrition {
            ViewThatFits(in: .horizontal) {
                // Side by side when there's enough space
                HStack(alignment: .top, spacing: 24) {
                    if hasIngredients {
                        ingredientsContent
                    }
                    if hasNutrition {
                        nutritionContent
                    }
                }
                // Stacked when space is limited
                VStack(alignment: .leading, spacing: 24) {
                    if hasIngredients {
                        ingredientsContent
                    }
                    if hasNutrition {
                        nutritionContent
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            AsyncImage(url: recipe.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    placeholderImage
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                case .failure:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 300)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .glassSection(in: RoundedRectangle(cornerRadius: 20))

            HStack {
                Text(recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if let rating = recipe.ratingValue {
                    ratingBadge(rating)
                }
            }
        }
    }

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.4),
                    Color.red.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func ratingBadge(_ rating: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)

            Text(String(format: "%.1f", rating))
                .fontWeight(.semibold)
        }
        .font(.title3)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassSection(in: Capsule())
    }

    @ViewBuilder
    private var timeSection: some View {
        let hasTime = recipe.displayPrepTime != nil || recipe.displayCookTime != nil || recipe.displayTotalTime != nil
        if hasTime {
            HStack(spacing: 16) {
                if let prep = recipe.displayPrepTime {
                    timeCard(label: "Prep", value: prep, icon: "clock")
                }
                if let cook = recipe.displayCookTime {
                    timeCard(label: "Cook", value: cook, icon: "flame")
                }
                if let total = recipe.displayTotalTime {
                    timeCard(label: "Total", value: total, icon: "timer")
                }
            }
        }
    }

    private func timeCard(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSection(in: RoundedRectangle(cornerRadius: 12))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Description", icon: "text.alignleft")

            Text(recipe.displayDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSection(in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var stepsSection: some View {
        if let steps = recipe.steps, !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Instructions", icon: "list.number")

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(steps.sorted(by: { $0.step < $1.step }), id: \.step) { step in
                        HStack(alignment: .top, spacing: 16) {
                            // Step number badge with glass effect
                            Text("\(step.step)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 28, height: 28)
                                .glassBadge()

                            // Instruction text
                            Text(step.instruction.cleanedHTML)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSection(in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var ingredientsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Ingredients", icon: "list.bullet")

            VStack(alignment: .leading, spacing: 8) {
                if let ingredients = recipe.ingredients {
                    ForEach(ingredients.prefix(15), id: \.self) { ingredient in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.secondary)
                                .frame(width: 6, height: 6)

                            Text(ingredient)
                                .font(.body)
                        }
                    }

                    if ingredients.count > 15 {
                        Text("... and \(ingredients.count - 15) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 18)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSection(in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var nutritionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Nutrition", icon: "leaf")
            if let nutrition = recipe.nutritionalInformation {
                NutritionLabelView(nutrition: nutrition)
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var backgroundGradient: some View {
        #if os(macOS)
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        #else
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        #endif
    }
}

#if os(macOS)
import AppKit
#endif

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe(
            id: "123",
            title: "Delicious Chocolate Cake",
            description: "A rich and moist chocolate cake that's perfect for any occasion.",
            ingredients: ["2 cups flour", "1.5 cups sugar", "3/4 cup cocoa powder"],
            steps: [
                RecipeStep(step: 1, instruction: "Preheat oven to 350 degrees F (175 degrees C)."),
                RecipeStep(step: 2, instruction: "Mix flour, sugar, and cocoa powder in a large bowl."),
                RecipeStep(step: 3, instruction: "Bake for 35 minutes or until a toothpick comes out clean.")
            ],
            rating: "4.8",
            images: nil,
            nutritionalInformation: NutritionInfo(
                calories: "350", servings: "8", totalFat: "14", saturatedFat: "8",
                cholesterol: "55", sodium: "320", potassium: "200", totalCarbohydrate: "52",
                dietryFibre: "2", protein: "5", sugars: "36", vitaminA: "4",
                vitaminC: "0", calcium: "4", iron: "15"
            ),
            prepTime: "PT20M",
            cookTime: "PT35M",
            totalTime: "PT55M"
        ))
    }
}
