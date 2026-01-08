import SwiftUI
#if os(macOS)
import AppKit
#endif

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

    var body: some View {
        ScrollView {
            RecipeFlowLayout(spacing: 12) {
                ForEach(results) { result in
                    RecipeCard(result: result, isSelected: selectedRecipe?.id == result.recipe.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedRecipe = result.recipe
                            }
                        }
                }
            }
            .padding(12)
        }
    }
}

/// Flow layout that wraps cards to the next row when they don't fit, centered
struct RecipeFlowLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let totalHeight = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)

        var currentY: CGFloat = 0
        var subviewIndex = 0

        for row in rows {
            // Center the row
            let rowOffset = (bounds.width - row.width) / 2

            var currentX = rowOffset
            for _ in 0..<row.count {
                let size = row.sizes[subviewIndex - (row.startIndex)]
                subviews[subviewIndex].place(
                    at: CGPoint(x: bounds.minX + currentX, y: bounds.minY + currentY),
                    proposal: ProposedViewSize(size)
                )
                currentX += size.width + spacing
                subviewIndex += 1
            }

            currentY += row.height + spacing
        }
    }

    private struct Row {
        var startIndex: Int
        var count: Int
        var width: CGFloat
        var height: CGFloat
        var sizes: [CGSize]
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row(startIndex: 0, count: 0, width: 0, height: 0, sizes: [])
        var currentX: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentRow.count > 0 {
                // Finish current row (remove trailing spacing from width)
                currentRow.width = currentX - spacing
                rows.append(currentRow)

                // Start new row
                currentRow = Row(startIndex: index, count: 0, width: 0, height: 0, sizes: [])
                currentX = 0
            }

            currentRow.count += 1
            currentRow.height = max(currentRow.height, size.height)
            currentRow.sizes.append(size)
            currentX += size.width + spacing
        }

        // Don't forget the last row
        if currentRow.count > 0 {
            currentRow.width = currentX - spacing
            rows.append(currentRow)
        }

        return rows
    }
}

struct RecipeCard: View {
    let result: SearchResult
    let isSelected: Bool

    private let cardHeight: CGFloat = 120
    private let minCardWidth: CGFloat = 140
    private let maxCardWidth: CGFloat = 220
    @State private var imageAspectRatio: CGFloat = 1.5  // Default 3:2 ratio

    private var cardWidth: CGFloat {
        let width = cardHeight * imageAspectRatio
        return min(max(width, minCardWidth), maxCardWidth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailSection
            contentSection
        }
        .frame(width: cardWidth)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .glassCard(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
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
                    .aspectRatio(contentMode: .fill)
                    .onAppear {
                        // Get the actual image aspect ratio
                        #if os(macOS)
                        if let nsImage = NSImage(contentsOf: result.recipe.thumbnailURL!) {
                            let ratio = nsImage.size.width / nsImage.size.height
                            if ratio > 0 {
                                imageAspectRatio = ratio
                            }
                        }
                        #endif
                    }
            case .failure:
                placeholderImage
            @unknown default:
                placeholderImage
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
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
                // Don't show percentage for text search (similarity = 1.0)
                if result.similarity < 1.0 {
                    Text("\(Int(result.similarity * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: result.similarity)
                }
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

            if let count = result.recipe.ratingCount, let countInt = Int(count), countInt > 0 {
                Text("(\(countInt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
                    ratingCount: "127",
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
