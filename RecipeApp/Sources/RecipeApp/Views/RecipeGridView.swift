import SwiftUI

// MARK: - Glass Effect Extension (iOS 26+ with fallback)
extension View {
    @ViewBuilder
    func glassCard(in shape: some Shape = RoundedRectangle(cornerRadius: 20)) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

struct RecipeGridView: View {
    let results: [SearchResult]
    @Binding var selectedRecipe: Recipe?

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(results) { result in
                    RecipeCard(result: result, isSelected: selectedRecipe?.id == result.recipe.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedRecipe = result.recipe
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct RecipeCard: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailSection
            contentSection
        }
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .glassCard(in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
            }
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: .black.opacity(0.1), radius: isSelected ? 12 : 6, y: isSelected ? 6 : 3)
    }

    private var thumbnailSection: some View {
        AsyncImage(url: result.recipe.thumbnailURL) { phase in
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
        .clipped()
    }

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.3),
                    Color.red.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "fork.knife")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.6))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.recipe.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack {
                if let rating = result.recipe.ratingValue {
                    ratingView(rating)
                }
                Spacer()
                Text("\(Int(result.similarity * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private func ratingView(_ rating: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .font(.caption)

            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RecipeGridView(
        results: [
            SearchResult(
                recipe: Recipe(
                    id: "123",
                    title: "Delicious Chocolate Cake",
                    description: "A rich and moist chocolate cake.",
                    ingredients: ["flour", "sugar", "cocoa"],
                    steps: nil,
                    rating: "4.5",
                    images: nil,
                    nutritionalInformation: nil,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil
                ),
                similarity: 0.85
            )
        ],
        selectedRecipe: .constant(nil)
    )
    .frame(width: 600, height: 400)
}
