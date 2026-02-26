//
//  QuiEventHandler.swift
//  qui
//
//  Created by Joe Cieplinski on 5/10/25.
//

import SwiftUI
import SwiftData
import OSLog
import WidgetKit

@ModelActor
actor QuiEventHandler {
  
  @AppStorage("lastUpdateDate") private var lastUpdateDate: Date = Date.distantPast
  
  public func fetch() async throws -> [QuiEventEntity] {
    // Clean up duplicates before fetching
    try await cleanupDuplicates()
    
    let descriptor = FetchDescriptor<QuiEvent>()
    let fetchedEvents = try modelContext.fetch(descriptor).sorted{ $0.date < $1.date }
    
    // Deduplicate events based on their unique ID
    var seenIds = Set<UUID>()
    let uniqueEvents = fetchedEvents.compactMap { event -> QuiEvent? in
      if seenIds.contains(event.id) {
        return nil // Skip duplicate
      }
      seenIds.insert(event.id)
      return event
    }.sorted { $0.date < $1.date }
    
    return uniqueEvents.map(QuiEventEntity.init)
  }
  
  public func fetchEventsFromDatabase() async throws -> [QuiEventEntity] {
    // Clean up duplicates before fetching
    try await cleanupDuplicates()
    
    let descriptor = FetchDescriptor<QuiEvent>()
    let fetchedEvents = try modelContext.fetch(descriptor).sorted{ $0.date < $1.date }
    
    // Deduplicate events based on their unique ID
    var seenIds = Set<UUID>()
    let uniqueEvents = fetchedEvents.compactMap { event -> QuiEvent? in
      if seenIds.contains(event.id) {
        return nil // Skip duplicate
      }
      seenIds.insert(event.id)
      return event
    }.sorted { $0.date < $1.date }
    
    return uniqueEvents.map(QuiEventEntity.init)
  }
  
  public func fetchEventsFromDatabaseWithIds() async throws -> [UUID] {
    // Clean up duplicates before fetching
    try await cleanupDuplicates()
    
    let descriptor = FetchDescriptor<QuiEvent>()
    let fetchedEvents = try modelContext.fetch(descriptor).sorted{ $0.date < $1.date }
    
    // Deduplicate events based on their unique ID
    var seenIds = Set<UUID>()
    let uniqueEvents = fetchedEvents.compactMap { event -> QuiEvent? in
      if seenIds.contains(event.id) {
        return nil // Skip duplicate
      }
      seenIds.insert(event.id)
      return event
    }.sorted { $0.date < $1.date }
    
    return uniqueEvents.map { $0.id }
  }
  
  public func cleanupDuplicates() async throws {
    let descriptor = FetchDescriptor<QuiEvent>()
    let allEvents = try modelContext.fetch(descriptor)
    
    Logger.swiftData.info("Starting duplicate cleanup. Total events in database: \(allEvents.count)")
    
    // Group events by ID to find duplicates
    let groupedEvents = Dictionary(grouping: allEvents) { $0.id }
    
    var totalDuplicatesRemoved = 0
    
    // For each group of events with the same ID, keep only the first one
    for (id, events) in groupedEvents {
      if events.count > 1 {
        Logger.swiftData.info("Found \(events.count) duplicate events with ID \(id), keeping the first one")
        Logger.swiftData.info("Duplicate event titles: \(events.map { $0.title })")
        
        // Keep the first event, delete the rest
        let eventsToDelete = Array(events.dropFirst())
        for event in eventsToDelete {
          modelContext.delete(event)
          totalDuplicatesRemoved += 1
        }
      }
    }
    
    // Also check for duplicates by title, date, and location (in case UUID parsing failed)
    let titleDateGrouped = Dictionary(grouping: allEvents) { event in
      "\(event.title)|\(event.date.timeIntervalSince1970)|\(event.location)"
    }
    
    for (key, events) in titleDateGrouped {
      if events.count > 1 {
        Logger.swiftData.info("Found \(events.count) events with same title/date/location: \(key)")
        Logger.swiftData.info("Event titles: \(events.map { $0.title })")
        Logger.swiftData.info("Event IDs: \(events.map { $0.id })")
        
        // Keep the first event, delete the rest
        let eventsToDelete = Array(events.dropFirst())
        for event in eventsToDelete {
          modelContext.delete(event)
          totalDuplicatesRemoved += 1
        }
      }
    }
    
    if totalDuplicatesRemoved > 0 {
      Logger.swiftData.info("Removed \(totalDuplicatesRemoved) duplicate events")
      try modelContext.save()
    } else {
      Logger.swiftData.info("No duplicates found")
    }
  }
  
  public func forceCleanup() async throws {
    Logger.swiftData.info("Force cleanup initiated")
    try await cleanupDuplicates()
  }
  
  public func debugDatabase() async throws {
    let descriptor = FetchDescriptor<QuiEvent>()
    let allEvents = try modelContext.fetch(descriptor)
    
    Logger.swiftData.info("=== DATABASE DEBUG ===")
    Logger.swiftData.info("Total events: \(allEvents.count)")
    
    // Group by ID
    let groupedById = Dictionary(grouping: allEvents) { $0.id }
    for (id, events) in groupedById {
      if events.count > 1 {
        Logger.swiftData.info("DUPLICATE ID \(id): \(events.count) events")
        for (index, event) in events.enumerated() {
          Logger.swiftData.info("  \(index): \(event.title) at \(event.date) - \(event.location)")
        }
      }
    }
    
    // Group by title + date + location
    let groupedByTitle = Dictionary(grouping: allEvents) { event in
      "\(event.title)|\(event.date.timeIntervalSince1970)|\(event.location)"
    }
    
    for (key, events) in groupedByTitle {
      if events.count > 1 {
        Logger.swiftData.info("DUPLICATE TITLE/DATE/LOCATION: \(key)")
        for (index, event) in events.enumerated() {
          Logger.swiftData.info("  \(index): ID \(event.id) - \(event.title) at \(event.date)")
        }
      }
    }
    
    Logger.swiftData.info("=== END DEBUG ===")
  }
  
  public func updateFromWeb(imageCache: ImageCache) async throws {
    do {
      // Clean up any existing duplicates first
      try await cleanupDuplicates()
      
      // Fetch new events from web API
      let newEvents = try await fetchEvents()
      let newSpecialEvents = try await fetchSpecialEvents()
      
      Logger.urlSession.info("Fetched \(newEvents.count) events")
      Logger.urlSession.info("Fetched \(newSpecialEvents.count) special events")
      
      // Get existing events from database
      let descriptor = FetchDescriptor<QuiEvent>()
      let existingEvents = try modelContext.fetch(descriptor)
      
      // Keep track of today's events and future events using Pacific timezone
      var pacificCalendar = Calendar.current
      pacificCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
      let today = pacificCalendar.startOfDay(for: Date().convertedToPacificTime())
      let todaysEvents = existingEvents.filter { pacificCalendar.startOfDay(for: $0.date) == today }
      let futureEvents = existingEvents.filter { pacificCalendar.startOfDay(for: $0.date) > today }
      
      // Collect URLs of images we want to keep
      var imageURLsToKeep = Set<URL>()
      for event in newEvents + newSpecialEvents + todaysEvents + futureEvents {
        if let imageURLString = event.imageURL,
           let imageURL = URL(string: imageURLString) {
          imageURLsToKeep.insert(imageURL)
        }
      }
      
      // Clean up image cache
      await imageCache.cleanup(keeping: imageURLsToKeep)
      
      // Combine all new events and remove duplicates based on ID
      let allNewEvents = newEvents + newSpecialEvents
      
      // Create a set of IDs from the new events for efficient lookup
      let newEventIds = Set(allNewEvents.map { $0.id })
      
      // Delete past events and events removed from feeds
      // This prevents data loss if the main events API is temporarily down
      // Special events are always processed regardless of main events status
      var cleanupCalendar = Calendar.current
      cleanupCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
      let cleanupToday = cleanupCalendar.startOfDay(for: Date().convertedToPacificTime())
      
      // Track which events are being kept (not deleted)
      var eventsToKeep = Set<UUID>()
      
      for event in existingEvents {
        let isPast = cleanupCalendar.startOfDay(for: event.date) < cleanupToday
        
        // Determine if event should be removed from feed
        var isRemovedFromFeed = false
        if !newEvents.isEmpty {
          // If main events are available, remove events not in the combined feed
          isRemovedFromFeed = !newEventIds.contains(event.id)
        } else {
          // If main events are empty, preserve existing events to prevent data loss
          // Special events will still be added/updated, but we won't delete existing events
          // This ensures data isn't lost when the main feed is temporarily down
          isRemovedFromFeed = false
        }
        
        if isPast || isRemovedFromFeed {
          if isRemovedFromFeed {
            Logger.swiftData.info("Removing event no longer in feed: \(event.title) (\(event.id))")
          }
          modelContext.delete(event)
        } else {
          eventsToKeep.insert(event.id)
        }
      }
      
      if newEvents.isEmpty {
        Logger.urlSession.warning("Regular events are empty - preserving existing events, but still updating special events")
      }
      
      // Remove duplicates from new events based on ID
      var seenIds = Set<UUID>()
      let uniqueNewEvents = allNewEvents.compactMap { event -> QuiEvent? in
        if seenIds.contains(event.id) {
          return nil // Skip duplicate
        }
        seenIds.insert(event.id)
        return event
      }
      
      // Create a dictionary of existing events by ID for efficient lookup
      // Only include events that are being kept (not deleted)
      let existingEventsById = Dictionary(existingEvents.filter { eventsToKeep.contains($0.id) }.map { ($0.id, $0) }, 
                                         uniquingKeysWith: { first, _ in first })
      
      // Update existing events or insert new ones
      for newEvent in uniqueNewEvents {
        if let existingEvent = existingEventsById[newEvent.id] {
          // Update existing event with new data
          existingEvent.title = newEvent.title
          existingEvent.subtitle = newEvent.subtitle
          existingEvent.type = newEvent.type
          existingEvent.location = newEvent.location
          existingEvent.date = newEvent.date
          existingEvent.timeTBD = newEvent.timeTBD
          existingEvent.performers = newEvent.performers
          existingEvent.url = newEvent.url
          existingEvent.imageURL = newEvent.imageURL
          existingEvent.source = newEvent.source
        } else {
          // Insert new event
          modelContext.insert(newEvent)
        }
      }
      
      // Save changes
      try modelContext.save()
      
      // Update lastUpdateDate
      lastUpdateDate = Date()
      
      // Reload all widget timelines to reflect the updated events
      WidgetCenter.shared.reloadAllTimelines()
      
      Logger.swiftData.info("Successfully updated database with \(uniqueNewEvents.count) new events")
      
    } catch {
      Logger.swiftData.error("Error updating from web: \(error)")
      throw error
    }
  }
  
  private func fetchEvents() async throws -> [QuiEvent] {
    guard let url = URL(string: Constants.eventsAPIEndpoint) else {
      throw URLError(.badURL)
    }
    
    do {
      let (data, _) = try await URLSession(configuration: .ephemeral).data(from: url)
      
      let decoder = JSONDecoder()
      
      do {
        return try decoder.decode([QuiEvent].self, from: data)
      } catch {
        Logger.urlSession.error("Failed to decode events JSON: \(error.localizedDescription)")
        if let jsonString = String(data: data, encoding: .utf8) {
          Logger.urlSession.error("Response data: \(jsonString.prefix(500))")
        }
        throw URLError(.cannotParseResponse)
      }
      
    } catch let error as URLError {
      throw error
    } catch {
      throw URLError(.unknown)
    }
  }
  
  func fetchSpecialEvents() async throws -> [QuiEvent] {
    guard let url = URL(string: Constants.specialEventsAPIEndpoint) else {
      throw URLError(.badURL)
    }
    
    do {
      let (data, _) = try await URLSession(configuration: .ephemeral).data(from: url)
      
      let decoder = JSONDecoder()
      
      do {
        let allSpecialEvents = try decoder.decode([QuiEvent].self, from: data)
        
        // Filter out past events using Pacific timezone
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let today = calendar.startOfDay(for: Date().convertedToPacificTime())
        return allSpecialEvents.filter { event in
          calendar.startOfDay(for: event.date) >= today
        }
      } catch {
        Logger.urlSession.error("Failed to decode special events JSON: \(error.localizedDescription)")
        if let jsonString = String(data: data, encoding: .utf8) {
          Logger.urlSession.error("Response data: \(jsonString.prefix(500))")
        }
        throw URLError(.cannotParseResponse)
      }
      
    } catch let error as URLError {
      throw error
    } catch {
      throw URLError(.unknown)
    }
  }
}
