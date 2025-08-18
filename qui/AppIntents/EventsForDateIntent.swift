//
//  EventsForDateIntent.swift
//  qui
//
//  Created by Joe Cieplinski on 5/9/25.
//

import AppIntents
import Foundation
import SwiftUI
import SwiftData

struct EventsForDateIntent: AppIntent {
  typealias Value = String
  
  @Parameter(title: "Day")
  var day: Date?
  
  init() {}
  
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
  
  static var title: LocalizedStringResource = "Events for a provided date"
  static var description = IntentDescription("Shows events happening near you on a specific date you provide")
  static var openAppWhenRun: Bool = false
  
  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let handler = QuiEventHandler(modelContainer: sharedModelContainer)
    let events = try await handler.fetch()
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    
    guard let day else { return .result(value: "No Date Specified", dialog: "I need to know which day you mean") }
    
    if let todayEvent = events.filter({ calendar.startOfDay(for: $0.date) == calendar.startOfDay(for: day) }).sorted(by: { $0.date < $1.date }).first {
      return .result(
        value: todayEvent.title,
        dialog: "\(todayEvent.title) at \(todayEvent.location) on \(todayEvent.date.formatted(date: .abbreviated, time: .shortened))"
      )
    }
    
    return .result(
      value: "No Events on \(day.formatted(date: .abbreviated, time: .omitted))",
      dialog: "No Events on \(day.formatted(date: .abbreviated, time: .omitted))"
    )
  }
}
