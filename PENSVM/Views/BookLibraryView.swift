import SwiftUI

struct BookLibraryView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var books: [BookLibraryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if books.isEmpty {
                emptyView
            } else {
                bookList
            }
        }
        .onAppear {
            loadBooks()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            Text("Loading books...")
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
                loadBooks()
            }
            .buttonStyle(MinimalButtonStyle())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No books imported")
                .font(.custom("Palatino", size: 22))
                .foregroundColor(.black)
            Text("Use /import-chapter to add chapters")
                .font(.custom("Palatino", size: 16))
                .foregroundColor(.black.opacity(0.6))
            Spacer()
        }
    }

    private var bookList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(books) { book in
                    BookRow(book: book) {
                        viewModel.selectBook(book)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func loadBooks() {
        isLoading = true
        errorMessage = nil

        do {
            books = try ChapterStorageService.shared.loadBooks()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct BookRow: View {
    let book: BookLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.custom("Palatino", size: 18))
                        .foregroundColor(.black)
                    HStack(spacing: 8) {
                        if let author = book.author {
                            Text(author)
                                .font(.custom("Palatino", size: 14))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        Text("\(book.chapters.count) chapter\(book.chapters.count == 1 ? "" : "s")")
                            .font(.custom("Palatino", size: 14))
                            .foregroundColor(.black.opacity(0.4))
                    }
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
