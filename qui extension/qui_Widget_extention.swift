//
//  Qui_Widget_Extension.swift
//  Mission Rock Events Widget Extension
//
//  Created by Joe Cieplinski on 5/8/25.
//

import WidgetKit
import SwiftUI
import SwiftData
import OSLog

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    return SimpleEntry(
      date: Date(),
      configuration: ConfigurationAppIntent(),
      todayEvent: nil,
      todayEventImage: nil,
      eventIndex: 0,
      eventCount: 0
    )
  }
  
  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
    if let entry = await getTodayEntry(for: configuration, in: context) {
      return entry
    } else {
      return SimpleEntry(
        date: Date(),
        configuration: ConfigurationAppIntent(),
        todayEvent: nil,
        todayEventImage: nil,
        eventIndex: 0,
        eventCount: 0
      )
    }
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let nextMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)!

    if let entry = await getTodayEntry(for: configuration, in: context) {
      return Timeline(entries: [entry], policy: .after(nextMidnight))
    } else {
      let entry = SimpleEntry(
        date: Date(),
        configuration: ConfigurationAppIntent(),
        todayEvent: nil,
        todayEventImage: nil,
        eventIndex: 0,
        eventCount: 0
      )
      return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
  }
  
  private func getTodayEntry(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry? {
    let sharedModelContainer: ModelContainer = {
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
    
    do {
      // Use QuiEventHandler to get QuiEventEntity objects (which are Sendable)
      let handler = QuiEventHandler(modelContainer: sharedModelContainer)
      let events = try await handler.fetch()
      
      Logger.swiftData.info("Widget: Fetched \(events.count) events from QuiEventHandler")
      
      var calendar = Calendar.current
      calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
      let today = calendar.startOfDay(for: Date())
      let todayEvents = events.filter({ calendar.startOfDay(for: $0.date) == today })
      Logger.swiftData.info("Widget: Found \(todayEvents.count) events for today")
      
      let eventCount = todayEvents.count

      if eventCount > 0 {
        let defaults = UserDefaults.appGroup
        let storedDate = defaults.string(forKey: DefaultsKey.widgetEventDate) ?? ""
        let todayString = today.timeIntervalSince1970.description

        var eventIndex = defaults.integer(forKey: DefaultsKey.widgetEventIndex)
        if storedDate != todayString {
          eventIndex = 0
          defaults.set(0, forKey: DefaultsKey.widgetEventIndex)
          defaults.set(todayString, forKey: DefaultsKey.widgetEventDate)
        }

        let clampedIndex = max(0, min(eventIndex, eventCount - 1))
        if clampedIndex != eventIndex {
          defaults.set(clampedIndex, forKey: DefaultsKey.widgetEventIndex)
        }

        let todayEvent = todayEvents[clampedIndex]
        var image: UIImage?
        if let urlString = todayEvent.imageURL,
           let url = URL(string: urlString) {
          Logger.swiftData.info("Widget: Loading image from URL: \(url)")
          do {
            let imageData = try Data(contentsOf: url)
            if let fullImage = UIImage(data: imageData) {
              let maxDimension: CGFloat = 300
              let scale = min(maxDimension / fullImage.size.width, maxDimension / fullImage.size.height, 1.0)
              let newSize = CGSize(width: fullImage.size.width * scale, height: fullImage.size.height * scale)
              let renderer = UIGraphicsImageRenderer(size: newSize)
              image = renderer.image { _ in
                fullImage.draw(in: CGRect(origin: .zero, size: newSize))
              }
              Logger.swiftData.info("Widget: Image resized to \(Int(newSize.width))x\(Int(newSize.height))")
            }
          } catch {
            Logger.swiftData.error("Widget: Failed to load image: \(error)")
          }
        }
        return SimpleEntry(
          date: Date(),
          configuration: configuration,
          todayEvent: todayEvent,
          todayEventImage: image,
          eventIndex: clampedIndex,
          eventCount: eventCount
        )
      } else {
        Logger.swiftData.info("Widget: No events found for today")
        return SimpleEntry(
          date: Date(),
          configuration: configuration,
          todayEvent: nil,
          todayEventImage: nil,
          eventIndex: 0,
          eventCount: 0
        )
      }
    } catch {
      Logger.swiftData.error("Widget: Error fetching events: \(error)")
      // Return a simple entry with no event to prevent widget from crashing
      return SimpleEntry(date: Date(), configuration: configuration, todayEvent: nil, todayEventImage: nil, eventIndex: 0, eventCount: 0)
    }
  }
  
  //    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
  //        // Generate a list containing the contexts this widget is relevant in.
  //    }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationAppIntent
  let todayEvent: QuiEventEntity?
  let todayEventImage: UIImage?
  let eventIndex: Int
  let eventCount: Int
}

struct Qui_Widget_ExtensionEntryView : View {
  @Environment(\.widgetFamily) var family
  
  var entry: Provider.Entry
  
  var body: some View {
    VStack {
      switch family {
      case .systemSmall, .systemLarge, .systemMedium:
        if let todayEvent = entry.todayEvent {
          EntryCardWidgetView(
            event: todayEvent,
            image: entry.todayEventImage,
            eventIndex: entry.eventIndex,
            eventCount: entry.eventCount
          )
        } else {
          NoEventWidgetView(nextEvent: nil)
        }
      case .accessoryCircular:
        if let image = entry.todayEventImage {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
        } else {
          Text("No Events")
            .multilineTextAlignment(.center)
        }
      case .accessoryRectangular:
        if let todayEvent = entry.todayEvent {
          HStack {
            if let image = entry.todayEventImage {
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
            }
            
            Text(todayEvent.title)
              .lineLimit(2)
              .truncationMode(.tail)
          }
        } else {
          Text("No Events")
            .multilineTextAlignment(.center)
        }
      default:
        if let todayEvent = entry.todayEvent {
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
  SimpleEntry(date: .now, configuration: .smiley, todayEvent: nil, todayEventImage: nil, eventIndex: 0, eventCount: 0)
  SimpleEntry(date: .now, configuration: .starEyes, todayEvent: nil, todayEventImage: nil, eventIndex: 0, eventCount: 0)
}

#Preview(as: .accessoryInline) {
  Qui_Widget_Extension()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley, todayEvent: nil, todayEventImage: nil, eventIndex: 0, eventCount: 0)
}

#Preview(as: .accessoryCircular) {
  Qui_Widget_Extension()
} timeline: {
  SimpleEntry(date: .now, configuration: .smiley, todayEvent: nil, todayEventImage: nil, eventIndex: 0, eventCount: 0)
}
