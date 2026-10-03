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
  
  // Reusable URLSession for API calls
  private let urlSession = URLSession(configuration: .ephemeral)
  
  // Reusable Pacific timezone calendar
  private var pacificCalendar: Calendar {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return calendar
  }
  
  // Actor-safe storage for last update date
  private var lastUpdateDate: Date {
    get {
      UserDefaults.appGroup.object(forKey: "lastUpdateDate") as? Date ?? Date.distantPast
    }
    set {
      UserDefaults.appGroup.set(newValue, forKey: "lastUpdateDate")
    }
  }
  
  public func fetch() async throws -> [QuiEventEntity] {
    // Clean up duplicates before fetching
    try await cleanupDuplicates()
    
    let descriptor = FetchDescriptor<QuiEvent>()
    let fetchedEvents = try modelContext.fetch(descriptor)
    
    let uniqueEvents = deduplicateById(fetchedEvents).sorted { $0.date < $1.date }
    
    return uniqueEvents.map(QuiEventEntity.init)
  }
  
  public func fetchEventsFromDatabase() async throws -> [QuiEventEntity] {
    return try await fetch()
  }
  
  public func fetchEventsFromDatabaseWithIds() async throws -> [UUID] {
    // Clean up duplicates before fetching
    try await cleanupDuplicates()
    
    let descriptor = FetchDescriptor<QuiEvent>()
    let fetchedEvents = try modelContext.fetch(descriptor)
    
    let uniqueEvents = deduplicateById(fetchedEvents).sorted { $0.date < $1.date }
    
    return uniqueEvents.map { $0.id }
  }
  
  // Helper method to deduplicate events based on their unique ID
  private func deduplicateById(_ events: [QuiEvent]) -> [QuiEvent] {
    var seenIds = Set<UUID>()
    return events.compactMap { event -> QuiEvent? in
      if seenIds.contains(event.id) {
        return nil
      }
      seenIds.insert(event.id)
      return event
    }
  }
  
  public func cleanupDuplicates() async throws {
    let descriptor = FetchDescriptor<QuiEvent>()
    let allEvents = try modelContext.fetch(descriptor)
    
    Logger.swiftData.info("Starting duplicate cleanup. Total events in database: \(allEvents.count)")
    
    // Track events that have been deleted to avoid double deletion
    var deletedEvents = Set<UUID>()
    var totalDuplicatesRemoved = 0
    
    // Group events by ID to find duplicates
    let groupedEvents = Dictionary(grouping: allEvents) { $0.id }
    
    // For each group of events with the same ID, keep only the first one
    for (id, events) in groupedEvents {
      if events.count > 1 {
        Logger.swiftData.info("Found \(events.count) duplicate events with ID \(id), keeping the first one")
        Logger.swiftData.info("Duplicate event titles: \(events.map { $0.title })")
        
        // Keep the first event, delete the rest
        let eventsToDelete = Array(events.dropFirst())
        for event in eventsToDelete {
          modelContext.delete(event)
          deletedEvents.insert(event.id)
          totalDuplicatesRemoved += 1
        }
      }
    }
    
    // Also check for duplicates by title, date, and location (in case UUID parsing failed)
    // Only check events that haven't already been deleted
    let remainingEvents = allEvents.filter { !deletedEvents.contains($0.id) }
    let titleDateGrouped = Dictionary(grouping: remainingEvents) { event in
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
      
      await fillMissingSeatGeekImages(newEvents + newSpecialEvents)
      
      // Get existing events from database
      let descriptor = FetchDescriptor<QuiEvent>()
      let existingEvents = try modelContext.fetch(descriptor)
      
      // Keep track of today's events and future events using Pacific timezone
      let today = pacificCalendar.startOfDay(for: Date().convertedToPacificTime())
      let todaysEvents = existingEvents.filter { pacificCalendar.startOfDay(for: $0.date) == today }
      let futureEvents = existingEvents.filter { pacificCalendar.startOfDay(for: $0.date) > today }
      
      // Collect URLs of images we want to keep
      var imageURLsToKeep = Set<URL>()
      for event in newEvents + newSpecialEvents + todaysEvents + futureEvents {
        guard let imageURLString = event.imageURL else { continue }
        let trimmed = imageURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let imageURL = URL(string: trimmed),
              let scheme = imageURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
          Logger.imageCache.error("Unusable image URL for \(event.title, privacy: .public): \(imageURLString, privacy: .public)")
          continue
        }
        imageURLsToKeep.insert(imageURL)
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
      let cleanupToday = pacificCalendar.startOfDay(for: Date().convertedToPacificTime())
      
      // Track which events are being kept (not deleted)
      var eventsToKeep = Set<UUID>()
      
      for event in existingEvents {
        let isPast = pacificCalendar.startOfDay(for: event.date) < cleanupToday
        
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
      let uniqueNewEvents = deduplicateById(allNewEvents)
      
      // Create a dictionary of existing events by ID for efficient lookup
      // Only include events that are being kept (not deleted)
      let keptEvents = existingEvents.filter { eventsToKeep.contains($0.id) }
      var existingEventsById = Dictionary<UUID, QuiEvent>(minimumCapacity: keptEvents.count)
      for event in keptEvents {
        existingEventsById[event.id] = event
      }
      
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
      let (data, _) = try await urlSession.data(from: url)
      
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
  
  private func fetchSpecialEvents() async throws -> [QuiEvent] {
    guard let url = URL(string: Constants.specialEventsAPIEndpoint) else {
      throw URLError(.badURL)
    }
    
    do {
      let (data, _) = try await urlSession.data(from: url)
      
      let decoder = JSONDecoder()
      
      do {
        let allSpecialEvents = try decoder.decode([QuiEvent].self, from: data)
        
        // Filter out past events using Pacific timezone
        let today = pacificCalendar.startOfDay(for: Date().convertedToPacificTime())
        return allSpecialEvents.filter { event in
          pacificCalendar.startOfDay(for: event.date) >= today
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
  
  /// The events feed currently omits `image_url`. SeatGeek's event payload also
  /// leaves performer images blank; the performer record still has them.
  private func fillMissingSeatGeekImages(_ events: [QuiEvent]) async {
    let targets = events.compactMap { event -> (QuiEvent, String)? in
      let existing = event.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard existing.isEmpty, let eventID = Self.seatGeekEventID(from: event.url) else { return nil }
      return (event, eventID)
    }
    guard !targets.isEmpty else { return }
    
    Logger.imageCache.info("SeatGeek feed omitted image_url for \(targets.count) events. Resolving performer images.")
    
    let session = urlSession
    let eventIDs = Set(targets.map(\.1))
    var performerIDsByEvent: [String: [String]] = [:]
    await withTaskGroup(of: (String, [String]).self) { group in
      for eventID in eventIDs {
        group.addTask {
          let ids = await Self.performerIDs(forSeatGeekEvent: eventID, session: session)
          return (eventID, ids)
        }
      }
      for await (eventID, ids) in group {
        performerIDsByEvent[eventID] = ids
      }
    }
    
    let performerIDs = Set(performerIDsByEvent.values.flatMap { $0 })
    var performers: [String: SeatGeekPerformerImage] = [:]
    await withTaskGroup(of: (String, SeatGeekPerformerImage?).self) { group in
      for performerID in performerIDs {
        group.addTask {
          let performer = await Self.performerImage(for: performerID, session: session)
          return (performerID, performer)
        }
      }
      for await (performerID, performer) in group {
        if let performer {
          performers[performerID] = performer
        }
      }
    }
    
    var filled = 0
    for (event, eventID) in targets {
      let ids = performerIDsByEvent[eventID] ?? []
      guard let imageURL = Self.preferredImage(performerIDs: ids, title: event.title, performerNames: event.performers, performers: performers) else {
        Logger.imageCache.error("No SeatGeek performer image for \(event.title, privacy: .public) (event \(eventID, privacy: .public))")
        continue
      }
      event.imageURL = imageURL
      filled += 1
    }
    
    Logger.imageCache.info("Resolved SeatGeek images for \(filled) of \(targets.count) events.")
  }
  
  private static func seatGeekEventID(from urlString: String?) -> String? {
    guard let urlString,
          let url = URL(string: urlString),
          let host = url.host?.lowercased(),
          host == "seatgeek.com" || host.hasSuffix(".seatgeek.com") else {
      return nil
    }
    let identifier = url.lastPathComponent
    guard !identifier.isEmpty, identifier.allSatisfy(\.isNumber) else { return nil }
    return identifier
  }
  
  private static func preferredImage(performerIDs: [String], title: String, performerNames: String?, performers: [String: SeatGeekPerformerImage]) -> String? {
    let candidates = performerIDs.compactMap { performers[$0] }
    let haystack = "\(title) \(performerNames ?? "")".lowercased()
    if let match = candidates.first(where: { candidate in
      let name = candidate.name.lowercased()
      return !name.isEmpty && haystack.contains(name)
    }) {
      return match.imageURL
    }
    return candidates.first?.imageURL
  }
  
  private static func performerIDs(forSeatGeekEvent eventID: String, session: URLSession) async -> [String] {
    guard let url = URL(string: "https://seatgeek.com/data/events/\(eventID)?include=performers"),
          let data = await seatGeekData(from: url, session: session),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let payload = json["data"] as? [String: Any],
          let relationships = payload["relationships"] as? [String: Any],
          let performers = relationships["performers"] as? [String: Any],
          let list = performers["data"] as? [[String: Any]] else {
      return []
    }
    return list.compactMap { $0["id"] as? String }
  }
  
  private static func performerImage(for performerID: String, session: URLSession) async -> SeatGeekPerformerImage? {
    guard let url = URL(string: "https://seatgeek.com/data/performers/\(performerID)"),
          let data = await seatGeekData(from: url, session: session),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let payload = json["data"] as? [String: Any],
          let attributes = payload["attributes"] as? [String: Any] else {
      return nil
    }
    
    let name = attributes["name"] as? String ?? ""
    var imageURL = attributes["image"] as? String ?? ""
    if imageURL.isEmpty, let images = attributes["images"] as? [String: Any] {
      imageURL = (images["huge"] as? String) ?? (images["banner"] as? String) ?? ""
    }
    guard !imageURL.isEmpty else { return nil }
    return SeatGeekPerformerImage(name: name, imageURL: imageURL)
  }
  
  private static func seatGeekData(from url: URL, session: URLSession) async -> Data? {
    var request = URLRequest(url: url)
    request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      return data
    } catch {
      Logger.imageCache.error("SeatGeek lookup failed for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }
}

private struct SeatGeekPerformerImage: Sendable {
  let name: String
  let imageURL: String
}
