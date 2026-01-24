import SwiftUI

struct ReadingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            if let page = viewModel.currentPage {
                bookSpreadLayout(page: page, geometry: geometry)
            } else {
                VStack {
                    Spacer()
                    Text("No page available")
                        .font(.custom("Palatino", size: 18))
                        .foregroundColor(.black.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.white)
        .overlay(alignment: .bottomTrailing) {
            Button(action: { viewModel.goToExercises() }) {
                Text("Exercises")
                    .font(.custom("Palatino", size: 14))
            }
            .buttonStyle(MinimalButtonStyle())
            .padding(16)
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(.rightArrow) {
            viewModel.nextPage()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.previousPage()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "nN")) { _ in
            viewModel.nextPage()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "pP")) { _ in
            viewModel.previousPage()
            return .handled
        }
    }

    @ViewBuilder
    private func bookSpreadLayout(page: Page, geometry: GeometryProxy) -> some View {
        let hasLeftMargin = page.hasLeftMargin
        let hasRightMargin = page.hasRightMargin
        let hasBothMargins = page.hasBothMargins
        let hasAnyMargin = hasLeftMargin || hasRightMargin

        // Check if content has column assignments (two-column layout)
        let hasColumnAssignments = page.content.contains { $0.column != nil }

        if hasColumnAssignments || hasBothMargins {
            // Two-column book spread layout
            twoColumnLayout(page: page, geometry: geometry, hasLeftMargin: hasLeftMargin, hasRightMargin: hasRightMargin, hasBothMargins: hasBothMargins)
        } else if hasAnyMargin {
            // Single-column with margin (legacy layout)
            singleColumnWithMarginLayout(page: page, geometry: geometry, hasLeftMargin: hasLeftMargin)
        } else {
            // No margin - full width single column
            PageContentView(page: page)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func twoColumnLayout(page: Page, geometry: GeometryProxy, hasLeftMargin: Bool, hasRightMargin: Bool, hasBothMargins: Bool) -> some View {
        // Margins are always 12.5%
        // Column widths adjust based on how many margins are present
        let marginWidth = geometry.size.width * 0.125
        let dividerWidth: CGFloat = 1

        // Calculate remaining width for content columns
        let marginCount = (hasLeftMargin ? 1 : 0) + (hasRightMargin ? 1 : 0)
        let totalMarginWidth = marginWidth * CGFloat(marginCount)
        let dividerCount = 1 + marginCount  // center divider + margin dividers
        let totalDividerWidth = dividerWidth * CGFloat(dividerCount)
        let availableContentWidth = geometry.size.width - totalMarginWidth - totalDividerWidth
        let columnWidth = availableContentWidth / 2

        HStack(spacing: 0) {
            // Left margin (if present)
            if hasLeftMargin {
                MarginStripView(assetPath: page.resolvedLeftMarginAssetPath)
                    .frame(width: marginWidth)

                Rectangle()
                    .frame(width: dividerWidth)
                    .foregroundColor(.black)
            }

            // Left content column
            PageContentView(page: page, column: "left")
                .frame(width: columnWidth)

            Rectangle()
                .frame(width: dividerWidth)
                .foregroundColor(.black)

            // Right content column
            PageContentView(page: page, column: "right")
                .frame(width: columnWidth)

            // Right margin (if present)
            if hasRightMargin {
                Rectangle()
                    .frame(width: dividerWidth)
                    .foregroundColor(.black)

                MarginStripView(assetPath: page.resolvedRightMarginAssetPath)
                    .frame(width: marginWidth)
            }
        }
    }

    @ViewBuilder
    private func singleColumnWithMarginLayout(page: Page, geometry: GeometryProxy, hasLeftMargin: Bool) -> some View {
        // Margins are always 12.5%
        let marginWidth = geometry.size.width * 0.125
        let contentWidth = geometry.size.width * 0.875 - 1

        HStack(spacing: 0) {
            if hasLeftMargin {
                // Margin on left (12.5%), content on right (87.5%)
                MarginStripView(assetPath: page.resolvedLeftMarginAssetPath)
                    .frame(width: marginWidth)

                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(.black)

                PageContentView(page: page)
                    .frame(width: contentWidth)
            } else {
                // Content on left (87.5%), margin on right (12.5%)
                PageContentView(page: page)
                    .frame(width: contentWidth)

                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(.black)

                MarginStripView(assetPath: page.resolvedRightMarginAssetPath)
                    .frame(width: marginWidth)
            }
        }
    }
}
