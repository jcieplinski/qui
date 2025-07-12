//
//  QuiApp.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/7/25.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct QuiApp: App {
  @AppStorage(DefaultsKey.lastFetch) private var lastFetch: Date?
  @State private var imageCache: ImageCache?
  @State private var defaultCache = ImageCache(diskCache: DiskImageCache())
  
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      QuiEvent.self,
    ])
    
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    
    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.imageCache as WritableKeyPath<EnvironmentValues, ImageCache>, imageCache ?? defaultCache)
        .task {
          if imageCache == nil {
            let cache = await ImageCache(diskCache: DiskImageCache())
            await cache.initialize()
            await MainActor.run {
              imageCache = cache
            }
          }
        }
        .onAppear {
          // We only want to fetch new data once per day
#if DEBUG
#else
          if let lastFetch, lastFetch.isToday() {
            return
          }
#endif
          
          Task {
            do {
              let cache = imageCache ?? defaultCache
              let handler = QuiEventHandler(modelContainer: sharedModelContainer)
              
#if DEBUG
              // Debug the database in debug mode
              do {
                try await handler.debugDatabase()
                try await handler.forceCleanup()
              } catch {
                Logger.swiftData.error("Debug error: \(error)")
              }
#endif
              
              try await handler.updateFromWeb(imageCache: cache)
              await MainActor.run {
                lastFetch = Date()
              }
            } catch {
              Logger.swiftData.error("Error fetching new stuff: \(error)")
            }
          }
        }
    }
    .modelContainer(sharedModelContainer)
  }
}
