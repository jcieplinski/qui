import SwiftUI
import ImageIO
import OSLog
import Observation

private struct ImageCacheKey: EnvironmentKey {
    static let defaultValue = ImageCache(diskCache: DiskImageCache())
}

extension EnvironmentValues {
    var imageCache: ImageCache {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}

private struct DecodedImage: @unchecked Sendable {
    let image: UIImage
}

private enum ImageLoadError: LocalizedError {
    case badStatus(Int, URL, String)
    case undecodable(URL, Int, String, String?)
    case remembered(String)

    var errorDescription: String? {
        switch self {
        case let .badStatus(code, url, contentType):
            return "HTTP \(code) (\(contentType)) for \(url.absoluteString)"
        case let .undecodable(url, bytes, contentType, snippet):
            if let snippet, !snippet.isEmpty {
                return "Could not decode \(bytes) bytes (\(contentType)) from \(url.absoluteString). Body: \(snippet)"
            }
            return "Could not decode \(bytes) bytes (\(contentType)) from \(url.absoluteString)"
        case let .remembered(message):
            return message
        }
    }
}

private func isImageCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError, urlError.code == .cancelled { return true }
    return false
}

/// Each image downloads on its own `URLSession` task.
///
/// `AsyncImage` shares one loader. A single failure or cancellation (common in
/// a `List`) leaves every other image stuck on its placeholder.
@Observable
final class ImageCache: @unchecked Sendable {
    private static let maxPixelSize: CGFloat = 800
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    @ObservationIgnored
    private let lock = NSLock()
    @ObservationIgnored
    private var memoryCache: [URL: UIImage] = [:]
    @ObservationIgnored
    private var failures: [URL: String] = [:]
    @ObservationIgnored
    private let diskCache: DiskImageCache

    init(diskCache: DiskImageCache) {
        self.diskCache = diskCache
    }

    func initialize() async {
        await diskCache.prepare()
    }

    func memoryImage(for url: URL) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return memoryCache[url]
    }

    func loadImage(for url: URL) async throws -> UIImage {
        if let cached = memoryImage(for: url) {
            return cached
        }
        if let message = failureMessage(for: url) {
            throw ImageLoadError.remembered(message)
        }
        if let diskImage = await diskCache.loadImage(for: url) {
            storeMemory(diskImage, for: url)
            return diskImage
        }

        Logger.imageCache.info("Downloading image \(url.absoluteString, privacy: .public)")
        do {
            let image = try await Self.download(url: url, session: Self.session)
            storeMemory(image, for: url)
            await diskCache.saveImage(image, for: url)
            return image
        } catch {
            if isImageCancellation(error) {
                throw error
            }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if Self.shouldRemember(error) {
                storeFailure(message, for: url)
            }
            Logger.imageCache.error("Image load failed: \(message, privacy: .public)")
            throw error
        }
    }

    func clearMemoryCache() {
        lock.lock()
        memoryCache.removeAll()
        failures.removeAll()
        lock.unlock()
    }

    func clearDiskCache() async {
        clearMemoryCache()
        await diskCache.cleanup(keeping: [])
    }

    func cleanup(keeping urls: Set<URL>) async {
        lock.lock()
        memoryCache = memoryCache.filter { urls.contains($0.key) }
        failures = failures.filter { urls.contains($0.key) }
        lock.unlock()
        await diskCache.cleanup(keeping: urls)
    }

    private func failureMessage(for url: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return failures[url]
    }

    private func storeMemory(_ image: UIImage, for url: URL) {
        lock.lock()
        memoryCache[url] = image
        failures.removeValue(forKey: url)
        lock.unlock()
    }

    private func storeFailure(_ message: String, for url: URL) {
        lock.lock()
        failures[url] = message
        lock.unlock()
    }

    private static func shouldRemember(_ error: Error) -> Bool {
        switch error {
        case let ImageLoadError.badStatus(code, _, _) where (400..<500).contains(code) && code != 408 && code != 429:
            return true
        case ImageLoadError.undecodable:
            return true
        default:
            return false
        }
    }

    private static func download(url: URL, session: URLSession) async throws -> UIImage {
        let (data, response) = try await session.data(from: url)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 200
        let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        guard (200..<300).contains(status) else {
            throw ImageLoadError.badStatus(status, url, contentType)
        }

        let decoded = await Task.detached(priority: .userInitiated) {
            Self.makeImage(data: data).map(DecodedImage.init)
        }.value
        guard let decoded else {
            let snippet = data.count < 300 ? String(data: data, encoding: .utf8) : nil
            throw ImageLoadError.undecodable(url, data.count, contentType, snippet)
        }
        return decoded.image
    }

    private static func makeImage(data: Data) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }

        // Thumbnail creation rejects some valid files. Avoid fully decoding a huge payload.
        guard data.count <= 8_000_000 else { return nil }
        return UIImage(data: data)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @Environment(\.imageCache) private var imageCache
    @State private var phase: Phase = .idle

    private enum Phase {
        case idle
        case loading
        case loaded(Image)
        case failed
    }

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            switch phase {
            case .loaded(let image):
                content(image)
            case .failed:
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Image failed to load")
            case .idle, .loading:
                if url == nil {
                    EmptyView()
                } else {
                    placeholder()
                }
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            phase = .idle
            return
        }
        if let cached = imageCache.memoryImage(for: url) {
            phase = .loaded(Image(uiImage: cached))
            return
        }

        phase = .loading
        do {
            let uiImage = try await imageCache.loadImage(for: url)
            phase = .loaded(Image(uiImage: uiImage))
        } catch {
            if isImageCancellation(error) { return }
            phase = .failed
        }
    }
}

#Preview {
    CachedAsyncImage(
        url: URL(string: "https://example.com/image.jpg")
    ) { image in
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
    } placeholder: {
        ProgressView()
    }
}
