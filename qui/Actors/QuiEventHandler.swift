//
//  QuiEventHandler.swift
//  qui
//
//  Created by Joe Cieplinski on 5/10/25.
//

import SwiftUI
import SwiftData
import OSLog

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
      
      guard !newEvents.isEmpty else { return }
      
      // Get existing events from database
      let descriptor = FetchDescriptor<QuiEvent>()
      let existingEvents = try modelContext.fetch(descriptor)
      
      // Create a set of existing event IDs for efficient lookup
      let existingEventIds = Set(existingEvents.map { $0.id })
      
      // Keep track of today's events and future events
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      let todaysEvents = existingEvents.filter { calendar.startOfDay(for: $0.date) == today }
      let futureEvents = existingEvents.filter { calendar.startOfDay(for: $0.date) > today }
      
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
      
      // Delete only past events (not today's or future events)
      for event in existingEvents {
        if calendar.startOfDay(for: event.date) < today {
          modelContext.delete(event)
        }
      }
      
      // Combine all new events and remove duplicates based on ID
      let allNewEvents = newEvents + newSpecialEvents
      var seenIds = Set<UUID>()
      let uniqueNewEvents = allNewEvents.compactMap { event -> QuiEvent? in
        if seenIds.contains(event.id) {
          return nil // Skip duplicate
        }
        seenIds.insert(event.id)
        return event
      }
      
      // Add new events, checking against existing events to avoid duplicates
      for newEvent in uniqueNewEvents {
        // Check if this event already exists in the database
        if existingEventIds.contains(newEvent.id) {
          // Update existing event with new data if needed
          if let existingEvent = existingEvents.first(where: { $0.id == newEvent.id }) {
            existingEvent.title = newEvent.title
            existingEvent.type = newEvent.type
            existingEvent.location = newEvent.location
            existingEvent.date = newEvent.date
            existingEvent.timeTBD = newEvent.timeTBD
            existingEvent.performers = newEvent.performers
            existingEvent.url = newEvent.url
            existingEvent.imageURL = newEvent.imageURL
            existingEvent.source = newEvent.source
          }
        } else {
          // This is a truly new event, insert it
          modelContext.insert(newEvent)
        }
      }
      
      try modelContext.save()
      
      // Update the last update date on successful completion
      lastUpdateDate = Date()
      
    } catch {
      Logger.swiftData.error("Error fetching new events from web API: \(error)")
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
        
        // Filter out past events
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allSpecialEvents.filter { event in
          calendar.startOfDay(for: event.date) >= today
        }
      } catch {
        throw URLError(.cannotParseResponse)
      }
      
    } catch let error as URLError {
      throw error
    } catch {
      throw URLError(.unknown)
    }
  }
}
