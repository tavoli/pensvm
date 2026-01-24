import SwiftUI

struct ChapterLibraryView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var chapters: [Chapter] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if chapters.isEmpty {
                emptyView
            } else {
                chapterList
            }
        }
        .onAppear {
            loadChapters()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            Text("Loading chapters...")
                .font(.custom("Palatino", size: 18))
                .foregroundColor(.black)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message)
                .font(.custom("Palatino", size: 18))
                .foregroundColor(.black)
            Button("Retry") {
                loadChapters()
            }
            .buttonStyle(MinimalButtonStyle())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No chapters imported")
                .font(.custom("Palatino", size: 22))
                .foregroundColor(.black)
            Text("Use /import-chapter to add chapters")
                .font(.custom("Palatino", size: 16))
                .foregroundColor(.black.opacity(0.6))
            Spacer()
        }
    }

    private var chapterList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(chapters) { chapter in
                    ChapterRow(chapter: chapter) {
                        viewModel.selectChapter(chapter)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func loadChapters() {
        isLoading = true
        errorMessage = nil

        do {
            chapters = try ChapterStorageService.shared.loadAllChapters()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct ChapterRow: View {
    let chapter: Chapter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(chapter.romanNumeral). \(chapter.title)")
                        .font(.custom("Palatino", size: 18))
                        .foregroundColor(.black)
                    Text("\(chapter.totalPages) pages")
                        .font(.custom("Palatino", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.black.opacity(0.1)),
            alignment: .bottom
        )
    }
}
