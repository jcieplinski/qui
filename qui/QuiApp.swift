//
//  QuiApp.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/7/25.
//

import SwiftUI
import SwiftData
import OSLog
import WidgetKit

@main
struct QuiApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(DefaultsKey.lastFetch) private var lastFetch: Date?
  @State private var imageCache: ImageCache?
  @State private var defaultCache = ImageCache(diskCache: DiskImageCache())
  
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      QuiEvent.self,
    ])
    
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      groupContainer: .identifier(Constants.appGroup)
    )

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
        .onChange(of: scenePhase) {
          if scenePhase == .active {
            Task {
              do {
                let cache = imageCache ?? defaultCache
                let handler = QuiEventHandler(modelContainer: sharedModelContainer)
                try await handler.updateFromWeb(imageCache: cache)
                await MainActor.run {
                  lastFetch = Date()
                }
              } catch {
                Logger.swiftData.error("Error refreshing on foreground: \(error)")
                WidgetCenter.shared.reloadAllTimelines()
              }
            }
          }
        }
    }
    .modelContainer(sharedModelContainer)
  }
}
