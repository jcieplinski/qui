//
//  Qui_Widget_Extension.swift
//  Mission Rock Events Widget Extension
//
//  Created by Joe Cieplinski on 5/8/25.
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
    let entry = SimpleEntry(date: Date(), configuration: configuration)
    
    return Timeline(entries: [entry], policy: .atEnd)
  }
  
  //    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
  //        // Generate a list containing the contexts this widget is relevant in.
  //    }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationAppIntent
}

struct Qui_Widget_ExtensionEntryView : View {
  @Environment(\.widgetFamily) var family
  
  var entry: Provider.Entry
  @Query(sort: \QuiEvent.date) private var events: [QuiEvent]
  
  var todayEvents: [QuiEvent] {
    return events.filter { $0.date.isToday() }.sorted { $0.date < $1.date }
  }
  
  var nextEvent: QuiEvent? {
    return events
      .filter { $0.date > Calendar.current.startOfDay(for: Date()) }
      .sorted { $0.date < $1.date }
      .first
  }
  
  var body: some View {
    VStack {
      switch family {
      case .systemSmall, .systemLarge, .systemMedium:
        if let todayEvent = todayEvents.first {
          EntryCardWidgetView(event: todayEvent)
        } else {
          NoEventWidgetView(nextEvent: nextEvent)
        }
      case .accessoryCircular:
        if let todayEvent = todayEvents.first {
          Image(todayEvent.eventType.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
        } else {
          Text("No Events")
            .multilineTextAlignment(.center)
        }
      case .accessoryRectangular:
        if let todayEvent = todayEvents.first {
          HStack {
            Image(todayEvent.eventType.image)
              .resizable()
              .aspectRatio(contentMode: .fit)
            
            Text(todayEvent.title)
              .lineLimit(2)
              .truncationMode(.tail)
          }
        } else {
          Text("No Events")
            .multilineTextAlignment(.center)
        }
      default:
        if let todayEvent = todayEvents.first {
          Text(todayEvent.title)
        } else {
          Text("No Events Today")
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

struct Qui_Widget_Extension: Widget {
  let kind: String = "Mission_Rock_Events_Widget_Extension"
  
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
      Qui_Widget_ExtensionEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
        .modelContainer(for: [QuiEvent.self])
    }
    .contentMarginsDisabled()
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .systemLarge,
      .accessoryCircular,
      .accessoryInline,
      .accessoryRectangular,
    ])
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

#Preview(as: .systemSmall) {
  Qui_Widget_Extension()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley)
  SimpleEntry(date: .now, configuration: .starEyes)
}

#Preview(as: .accessoryInline) {
  Qui_Widget_Extension()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley)
}

#Preview(as: .accessoryCircular) {
  Qui_Widget_Extension()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley)
}
