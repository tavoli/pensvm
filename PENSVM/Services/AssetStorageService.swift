import Foundation
import AppKit

/// Manages image asset storage for chapter pages and margin illustrations
class AssetStorageService {
    static let shared = AssetStorageService()

    private let fileManager = FileManager.default
    private let chapterStorage = ChapterStorageService.shared

    /// Chapters directory: ~/Library/Application Support/PENSVM/chapters/
    var chaptersDirectory: URL {
        chapterStorage.chaptersDirectory
    }

    private init() {}

    // MARK: - Directory Management

    /// Returns the directory for a specific chapter: chapters/ch-{NN}/
    func chapterDirectory(for chapterNumber: Int) -> URL {
        let paddedNumber = String(format: "%02d", chapterNumber)
        return chaptersDirectory.appendingPathComponent("ch-\(paddedNumber)")
    }

    /// Returns the pages subdirectory for a chapter: chapters/ch-{NN}/pages/
    func pagesDirectory(for chapterNumber: Int) -> URL {
        chapterDirectory(for: chapterNumber).appendingPathComponent("pages")
    }

    /// Returns the margins subdirectory for a chapter: chapters/ch-{NN}/margins/
    func marginsDirectory(for chapterNumber: Int) -> URL {
        chapterDirectory(for: chapterNumber).appendingPathComponent("margins")
    }

    /// Returns the illustrations subdirectory for a chapter: chapters/ch-{NN}/illustrations/
    func illustrationsDirectory(for chapterNumber: Int) -> URL {
        chapterDirectory(for: chapterNumber).appendingPathComponent("illustrations")
    }

    /// Returns the exercises subdirectory for a chapter: chapters/ch-{NN}/exercises/
    func exercisesDirectory(for chapterNumber: Int) -> URL {
        chapterDirectory(for: chapterNumber).appendingPathComponent("exercises")
    }

    /// Creates all subdirectories for a chapter if needed
    func ensureChapterDirectoriesExist(for chapterNumber: Int) throws {
        let directories = [
            chapterDirectory(for: chapterNumber),
            pagesDirectory(for: chapterNumber),
            marginsDirectory(for: chapterNumber),
            illustrationsDirectory(for: chapterNumber),
            exercisesDirectory(for: chapterNumber)
        ]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    throw StorageError.directoryCreationFailed
                }
            }
        }
    }

    // MARK: - Page Images

    /// Saves a full page image and returns the relative asset path
    /// - Parameters:
    ///   - imageData: PNG image data
    ///   - chapterNumber: The chapter number
    ///   - pageIndex: The page index (0-based)
    /// - Returns: Relative path like "chapters/ch-06/pages/page-00.png"
    func savePageImage(_ imageData: Data, chapterNumber: Int, pageIndex: Int) throws -> String {
        try ensureChapterDirectoriesExist(for: chapterNumber)

        let paddedChapter = String(format: "%02d", chapterNumber)
        let paddedIndex = String(format: "%02d", pageIndex)
        let filename = "page-\(paddedIndex).png"
        let relativePath = "chapters/ch-\(paddedChapter)/pages/\(filename)"

        let absoluteURL = chapterStorage.baseDirectory.appendingPathComponent(relativePath)

        do {
            try imageData.write(to: absoluteURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        return relativePath
    }

    /// Saves a page image from NSImage
    func savePageImage(_ image: NSImage, chapterNumber: Int, pageIndex: Int) throws -> String {
        guard let imageData = image.pngData else {
            throw StorageError.encodingFailed
        }
        return try savePageImage(imageData, chapterNumber: chapterNumber, pageIndex: pageIndex)
    }

    // MARK: - Margin Strip Images

    /// Saves a margin strip (entire left margin column) and returns the relative asset path
    /// - Parameters:
    ///   - imageData: PNG image data of the margin strip
    ///   - chapterNumber: The chapter number
    ///   - pageIndex: The page index (0-based)
    /// - Returns: Relative path like "chapters/ch-06/margins/margin-00.png"
    func saveMarginStrip(_ imageData: Data, chapterNumber: Int, pageIndex: Int) throws -> String {
        try ensureChapterDirectoriesExist(for: chapterNumber)

        let paddedChapter = String(format: "%02d", chapterNumber)
        let paddedIndex = String(format: "%02d", pageIndex)
        let filename = "margin-\(paddedIndex).png"
        let relativePath = "chapters/ch-\(paddedChapter)/margins/\(filename)"

        let absoluteURL = chapterStorage.baseDirectory.appendingPathComponent(relativePath)

        do {
            try imageData.write(to: absoluteURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        return relativePath
    }

    /// Saves a margin strip from NSImage
    func saveMarginStrip(_ image: NSImage, chapterNumber: Int, pageIndex: Int) throws -> String {
        guard let imageData = image.pngData else {
            throw StorageError.encodingFailed
        }
        return try saveMarginStrip(imageData, chapterNumber: chapterNumber, pageIndex: pageIndex)
    }

    // MARK: - Illustration Images

    /// Saves an illustration and returns the relative asset path
    /// - Parameters:
    ///   - imageData: PNG image data of the illustration
    ///   - chapterNumber: The chapter number
    ///   - illustrationIndex: The illustration index (0-based, sequential within chapter)
    /// - Returns: Relative path like "chapters/ch-06/illustrations/illus-00.png"
    func saveIllustration(_ imageData: Data, chapterNumber: Int, illustrationIndex: Int) throws -> String {
        try ensureChapterDirectoriesExist(for: chapterNumber)

        let paddedChapter = String(format: "%02d", chapterNumber)
        let paddedIndex = String(format: "%02d", illustrationIndex)
        let filename = "illus-\(paddedIndex).png"
        let relativePath = "chapters/ch-\(paddedChapter)/illustrations/\(filename)"

        let absoluteURL = chapterStorage.baseDirectory.appendingPathComponent(relativePath)

        do {
            try imageData.write(to: absoluteURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        return relativePath
    }

    /// Saves an illustration from NSImage
    func saveIllustration(_ image: NSImage, chapterNumber: Int, illustrationIndex: Int) throws -> String {
        guard let imageData = image.pngData else {
            throw StorageError.encodingFailed
        }
        return try saveIllustration(imageData, chapterNumber: chapterNumber, illustrationIndex: illustrationIndex)
    }

    // MARK: - Image Loading

    /// Returns the absolute URL for a relative asset path
    func absoluteURL(for relativePath: String) -> URL {
        chapterStorage.baseDirectory.appendingPathComponent(relativePath)
    }

    /// Loads an image from a relative asset path
    func loadImage(at relativePath: String) -> NSImage? {
        let url = absoluteURL(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    /// Loads image data from a relative asset path
    func loadImageData(at relativePath: String) -> Data? {
        let url = absoluteURL(for: relativePath)
        return try? Data(contentsOf: url)
    }

    // MARK: - Asset Deletion

    /// Deletes all assets for a chapter (the entire ch-{NN} directory)
    func deleteChapterAssets(for chapterNumber: Int) throws {
        let directory = chapterDirectory(for: chapterNumber)

        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    /// Deletes a specific asset
    func deleteAsset(at relativePath: String) throws {
        let url = absoluteURL(for: relativePath)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Asset Listing

    /// Lists all page assets for a chapter
    func listPageAssets(for chapterNumber: Int) -> [String] {
        let directory = pagesDirectory(for: chapterNumber)
        let paddedChapter = String(format: "%02d", chapterNumber)

        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        return files
            .filter { $0.hasPrefix("page-") && $0.hasSuffix(".png") }
            .sorted()
            .map { "chapters/ch-\(paddedChapter)/pages/\($0)" }
    }

    /// Lists all margin assets for a chapter
    func listMarginAssets(for chapterNumber: Int) -> [String] {
        let directory = marginsDirectory(for: chapterNumber)
        let paddedChapter = String(format: "%02d", chapterNumber)

        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        return files
            .filter { $0.hasPrefix("margin-") && $0.hasSuffix(".png") }
            .sorted()
            .map { "chapters/ch-\(paddedChapter)/margins/\($0)" }
    }

    /// Lists all illustration assets for a chapter
    func listIllustrationAssets(for chapterNumber: Int) -> [String] {
        let directory = illustrationsDirectory(for: chapterNumber)
        let paddedChapter = String(format: "%02d", chapterNumber)

        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        return files
            .filter { $0.hasPrefix("illus-") && $0.hasSuffix(".png") }
            .sorted()
            .map { "chapters/ch-\(paddedChapter)/illustrations/\($0)" }
    }

    /// Lists all asset files for a chapter (pages, margins, illustrations)
    func listAssets(for chapterNumber: Int) -> [String] {
        var assets: [String] = []
        assets.append(contentsOf: listPageAssets(for: chapterNumber))
        assets.append(contentsOf: listMarginAssets(for: chapterNumber))
        assets.append(contentsOf: listIllustrationAssets(for: chapterNumber))
        return assets
    }

    /// Checks if an asset exists
    func assetExists(at relativePath: String) -> Bool {
        let url = absoluteURL(for: relativePath)
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Image Cropping

    /// Margin column width as a fraction of page width (25%)
    static let marginRatio: CGFloat = 0.25

    /// Crops an image to a specified rectangle
    /// - Parameters:
    ///   - image: The source image
    ///   - rect: The rectangle to crop (in image coordinates, origin at top-left for CGImage)
    /// - Returns: The cropped image, or nil if cropping fails
    func cropImage(_ image: NSImage, to rect: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: rect) else {
            return nil
        }

        return NSImage(cgImage: croppedCGImage, size: NSSize(width: rect.width, height: rect.height))
    }

    /// Crops the left margin strip (25% of page width) from a page image
    /// - Parameters:
    ///   - sourceImage: The full page image
    ///   - chapterNumber: The chapter number
    ///   - pageIndex: The page index
    /// - Returns: The relative asset path, or nil if cropping/saving fails
    func cropAndSaveMarginStrip(
        from sourceImage: NSImage,
        chapterNumber: Int,
        pageIndex: Int
    ) throws -> String? {
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let marginWidth = imageWidth * Self.marginRatio

        let marginRect = CGRect(x: 0, y: 0, width: marginWidth, height: imageHeight)

        guard let croppedImage = cropImage(sourceImage, to: marginRect) else {
            return nil
        }

        return try saveMarginStrip(croppedImage, chapterNumber: chapterNumber, pageIndex: pageIndex)
    }

    /// Saves a cropped region from an image as an illustration
    /// - Parameters:
    ///   - sourceImage: The full page image
    ///   - rect: The bounding box of the illustration (in image coordinates)
    ///   - chapterNumber: The chapter number
    ///   - illustrationIndex: The illustration index
    /// - Returns: The relative asset path, or nil if cropping/saving fails
    func saveCroppedIllustration(
        from sourceImage: NSImage,
        rect: CGRect,
        chapterNumber: Int,
        illustrationIndex: Int
    ) throws -> String? {
        guard let croppedImage = cropImage(sourceImage, to: rect) else {
            return nil
        }

        return try saveIllustration(croppedImage, chapterNumber: chapterNumber, illustrationIndex: illustrationIndex)
    }
}

// MARK: - NSImage Extension

extension NSImage {
    /// Converts NSImage to PNG data
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
