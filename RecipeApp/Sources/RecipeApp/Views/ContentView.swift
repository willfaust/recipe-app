import SwiftUI

// MARK: - Glass Effect Extension (iOS 26+ with fallback)
extension View {
    @ViewBuilder
    func glassBackground(in shape: some Shape = RoundedRectangle(cornerRadius: 16)) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var searchEngine: RecipeSearchEngine
    @State private var selectedRecipe: Recipe?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationSplitView {
            mainContent
                #if os(macOS)
                .frame(minWidth: 600)
                #endif
        } detail: {
            if let recipe = selectedRecipe {
                RecipeDetailView(recipe: recipe)
            } else {
                emptyDetailView
            }
        }
        .task {
            await searchEngine.loadData()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isSearchFocused = true
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if searchEngine.isLoading {
            loadingView
        } else if let error = searchEngine.errorMessage {
            errorView(error)
        } else {
            searchableContent
        }
    }

    private var searchableContent: some View {
        VStack(spacing: 0) {
            searchHeader
            resultsContent
        }
        .background {
            backgroundGradient
        }
    }

    private var searchHeader: some View {
        VStack(spacing: 16) {
            Text("Recipe Search")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("Semantic search through 25k+ recipes")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            searchBar
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.title3)

            TextField("Search recipes...", text: $searchEngine.searchQuery)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(.primary)
                .focused($isSearchFocused)

            if !searchEngine.searchQuery.isEmpty {
                Button {
                    searchEngine.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .frame(maxWidth: 600)
    }

    @ViewBuilder
    private var resultsContent: some View {
        Group {
            if searchEngine.searchResults.isEmpty && searchEngine.searchQuery.isEmpty {
                emptySearchView
                    .transition(.opacity)
            } else if searchEngine.searchResults.isEmpty && searchEngine.showSearchingIndicator {
                searchingView
                    .transition(.opacity)
            } else if searchEngine.searchResults.isEmpty {
                noResultsView
                    .transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Search mode toggle and result count
                        searchModeBar

                        // Recipe grid with smooth animations
                        RecipeFlowLayout(spacing: 12) {
                            ForEach(searchEngine.searchResults) { result in
                                RecipeCard(result: result, isSelected: selectedRecipe?.id == result.recipe.id)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedRecipe = result.recipe
                                        }
                                    }
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchEngine.searchResults)

                        // Load more button
                        if searchEngine.hasMoreResults {
                            loadMoreButton
                        }
                    }
                    .padding(12)
                }
                .transition(.opacity)
                .overlay {
                    if searchEngine.showSearchingIndicator {
                        searchingOverlay
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: searchEngine.searchResults.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: searchEngine.searchQuery.isEmpty)
    }

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Searching...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchingOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding()
        }
    }

    private var searchModeBar: some View {
        HStack {
            // Result count
            Text("\(searchEngine.searchResults.count) of \(searchEngine.totalResultCount) results")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Search mode toggle
            HStack(spacing: 8) {
                Button {
                    searchEngine.setSearchMode(.semantic)
                } label: {
                    Label("Semantic", systemImage: "brain")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(searchEngine.searchMode == .semantic ? .blue : .gray)

                Button {
                    searchEngine.setSearchMode(.text)
                } label: {
                    Label("Text", systemImage: "text.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(searchEngine.searchMode == .text ? .blue : .gray)
            }
        }
        .padding(.horizontal, 4)
    }

    private var loadMoreButton: some View {
        Button {
            searchEngine.loadMore()
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle")
                Text("Load 20 more")
            }
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .glassButton()
        .tint(.blue)
        .padding(.vertical, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(searchEngine.loadingStatus)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Error Loading Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await searchEngine.loadData()
                }
            }
            .glassProminentButton()
            .tint(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }

    private var emptySearchView: some View {
        VStack(spacing: 24) {
            Image(systemName: "fork.knife")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("Start Searching")
                .font(.title2)
                .fontWeight(.medium)

            Text("Type a query to find recipes\nusing semantic search")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            suggestionChips
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionChips: some View {
        let suggestions = ["healthy chicken", "chocolate dessert", "quick pasta", "spicy tacos", "vegetarian dinner"]

        return FlowLayout(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(suggestion) {
                    searchEngine.searchQuery = suggestion
                }
                .glassButton()
                .tint(.blue)
            }
        }
        .padding(.horizontal, 32)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Results")
                .font(.title2)
                .fontWeight(.medium)

            Text("Try a different search query")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.document")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Select a Recipe")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Cross-platform color helper
#if os(macOS)
import AppKit
extension Color {
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
}
#endif

// MARK: - Flow Layout for suggestion chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecipeSearchEngine())
}
