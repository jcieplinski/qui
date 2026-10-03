import Foundation
import SwiftUI
import CryptoKit
import OSLog

actor DiskImageCache {
  private var cacheDirectory: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("ImageCache", isDirectory: true)
  }

  private func cacheKey(for url: URL) -> String {
    let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  init() {}

  func prepare() {
    createCacheDirectoryIfNeeded()
  }

  private func createCacheDirectoryIfNeeded() {
    let directory = cacheDirectory
    guard !FileManager.default.fileExists(atPath: directory.path) else { return }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      Logger.imageCache.error("Failed to create cache directory: \(error.localizedDescription, privacy: .public)")
    }
  }

  func saveImage(_ image: UIImage, for url: URL) async {
    createCacheDirectoryIfNeeded()
    guard let data = image.jpegData(compressionQuality: 0.8) else {
      Logger.imageCache.error("Failed to convert image to data for URL: \(url.absoluteString, privacy: .public)")
      return
    }

    let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: url))

    do {
      try data.write(to: fileURL)
      Logger.imageCache.debug("Saved image to disk for URL: \(url.absoluteString, privacy: .public)")
    } catch {
      Logger.imageCache.error("Failed to save image to disk for URL: \(url.absoluteString, privacy: .public), error: \(error.localizedDescription, privacy: .public)")
    }
  }

  func loadImage(for url: URL) async -> UIImage? {
    createCacheDirectoryIfNeeded()
    let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: url))

    guard let data = try? Data(contentsOf: fileURL),
          let image = UIImage(data: data) else {
      return nil
    }

    Logger.imageCache.debug("Loaded image from disk for URL: \(url.absoluteString, privacy: .public)")
    return image
  }

  func removeImage(for url: URL) async {
    let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: url))

    do {
      try FileManager.default.removeItem(at: fileURL)
      Logger.imageCache.debug("Removed image from disk for URL: \(url.absoluteString, privacy: .public)")
    } catch {
      Logger.imageCache.error("Failed to remove image from disk for URL: \(url.absoluteString, privacy: .public), error: \(error.localizedDescription, privacy: .public)")
    }
  }

  func cleanup(keeping urls: Set<URL>) async {
    createCacheDirectoryIfNeeded()
    do {
      let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
      let keptKeys = Set(urls.map { cacheKey(for: $0) })

      for fileURL in fileURLs where !keptKeys.contains(fileURL.lastPathComponent) {
        do {
          try FileManager.default.removeItem(at: fileURL)
          Logger.imageCache.debug("Cleaned up unused image: \(fileURL.lastPathComponent, privacy: .public)")
        } catch {
          Logger.imageCache.error("Failed to remove unused image \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
      }
    } catch {
      Logger.imageCache.error("Failed to cleanup disk cache: \(error.localizedDescription, privacy: .public)")
    }
  }
}
