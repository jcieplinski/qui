//
//  qui_watch_complications_extension.swift
//  qui watch complications extension
//
//  Created by Joe Cieplinski on 5/10/25.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
  }
  
  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
    SimpleEntry(date: Date(), configuration: configuration)
  }
  
  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
    var entries: [SimpleEntry] = []
    
    // Generate a timeline consisting of five entries an hour apart, starting from the current date.
    let currentDate = Date()
    for hourOffset in 0 ..< 5 {
      let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
      let entry = SimpleEntry(date: entryDate, configuration: configuration)
      entries.append(entry)
    }
    
    return Timeline(entries: entries, policy: .atEnd)
  }
  
  func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
    // Create an array with all the preconfigured widgets to show.
    [AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "qui Today Events")]
  }
  
  //    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
  //        // Generate a list containing the contexts this widget is relevant in.
  //    }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationAppIntent
}

struct qui_watch_complications_extensionEntryView : View {
  @Environment(\.widgetFamily) var family
  @Environment(\.modelContext) private var modelContext
  
  var entry: Provider.Entry
  @State private var events: [QuiEvent] = []
  
  var todayEvents: [QuiEvent] {
    return events.filter { $0.date.isToday() }.sorted { $0.date < $1.date }
  }
  
  var nextEvent: QuiEvent? {
    return events
      .filter { $0.date > Calendar.current.startOfDay(for: Date()) }
      .sorted { $0.date < $1.date }
      .first
  }
  
  private func loadEvents() async {
    do {
      let descriptor = FetchDescriptor<QuiEvent>()
      let fetchedEvents = try modelContext.fetch(descriptor).sorted { $0.date < $1.date }
      
      // Enhanced deduplication: first by ID, then by title/date/location
      var seenIds = Set<UUID>()
      var seenTitleDateLocation = Set<String>()
      
      events = fetchedEvents.compactMap { event -> QuiEvent? in
        // Check for ID duplicates
        if seenIds.contains(event.id) {
          return nil // Skip duplicate
        }
        
        // Check for title/date/location duplicates (in case UUID parsing failed)
        let titleDateLocationKey = "\(event.title)|\(event.date.timeIntervalSince1970)|\(event.location)"
        if seenTitleDateLocation.contains(titleDateLocationKey) {
          return nil // Skip duplicate
        }
        
        seenIds.insert(event.id)
        seenTitleDateLocation.insert(titleDateLocationKey)
        return event
      }.sorted { $0.date < $1.date }
    } catch {
      print("Error loading events: \(error)")
    }
  }
  
  var body: some View {
    VStack {
      switch family {
      case .accessoryCorner:
        ZStack {
          AccessoryWidgetBackground()
          Text("\(todayEvents.count)")
        }
        .widgetLabel {
          if let first = todayEvents.first {
            Text(first.title)
          } else {
            Text("No qui Events")
          }
        }
      case .accessoryCircular:
        ZStack {
          AccessoryWidgetBackground()
          Text("\(todayEvents.count)")
        }
        .widgetLabel {
          if let first = todayEvents.first {
            Text(first.title)
          } else {
            Text("No qui Events")
          }
        }
      case .accessoryRectangular:
        if let first = todayEvents.first {
          HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading) {
              Text(first.title)
                .font(.headline)
                .widgetAccentable()
              Text(first.date.formatted(date: .abbreviated, time: .shortened))
              Text(first.location)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        } else {
          HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading) {
              Text("No qui Events Today")
                .font(.headline)
                .widgetAccentable()
              if let nextEvent {
                Text("Next: \(nextEvent.title)")
                Text(nextEvent.date.formatted(date: .numeric, time: .shortened))
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      case .accessoryInline:
        if let first = todayEvents.first {
          Text(first.title)
        } else {
          Text("No qui Events")
        }
      @unknown default:
        Text("\(todayEvents.count)")
      }
    }
    .onAppear {
      Task {
        await loadEvents()
      }
    }
  }
}

@main
struct qui_watch_complications_extension: Widget {
  let kind: String = "qui_watch_complications_extension"
  
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
      qui_watch_complications_extensionEntryView(entry: entry)
        .modelContainer(for: [QuiEvent.self])
        .containerBackground(.fill.tertiary, for: .widget)
    }
  }
}

extension ConfigurationAppIntent {
  fileprivate static var smiley: ConfigurationAppIntent {
    let intent = ConfigurationAppIntent()
    return intent
  }
  
  fileprivate static var starEyes: ConfigurationAppIntent {
    let intent = ConfigurationAppIntent()
    return intent
  }
}

#Preview(as: .accessoryRectangular) {
  qui_watch_complications_extension()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley)
  SimpleEntry(date: .now, configuration: .starEyes)
}
