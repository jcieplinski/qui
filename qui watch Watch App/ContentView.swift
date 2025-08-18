//
//  ContentView.swift
//  qui watch Watch App
//
//  Created by Joe Cieplinski on 5/9/25.
//

import SwiftUI
import SwiftData
import WidgetKit
import WatchKit

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.imageCache) private var imageCache
  @State private var events: [QuiEvent] = []
  
  @State private var selectedDate: Date = Date().startOfDayInPacificTime()
  @State private var currentEvent: QuiEvent?
  @State private var showDatePicker: Bool = false
  @State private var showEventList: Bool = false
  @State private var showInfo: Bool = false
  @State private var isBackgroundRefreshing: Bool = false
  @State private var isLoadingEvents: Bool = false
  @State private var isInitialFetching: Bool = false
  @AppStorage("lastUpdateDate") private var lastUpdateDate: Date = Date.distantPast
  
  let dateFormatter = DateFormatter()
  
  var navigationTitle: String {
    if selectedDate.isToday() {
      return "Today"
    }
    
    return selectedDate.formatted(date: .abbreviated, time: .omitted)
  }
  
  var eventsForSelectedDate: [QuiEvent] {
    // Use Pacific timezone for date comparison
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    
    return events.filter {
      calendar.startOfDay(for: $0.date) == calendar.startOfDay(for: selectedDate)
    }.sorted { $0.date < $1.date }
  }
  
  var nextEventAfter: QuiEvent? {
    return events
      .filter { $0.date > selectedDate }
      .sorted { $0.date < $1.date }
      .first
  }
  
  private func loadEvents() {
    // Prevent multiple simultaneous loads
    guard !isLoadingEvents else { return }
    isLoadingEvents = true
    
    Task {
      do {
        let handler = QuiEventHandler(modelContainer: modelContext.container)
        let eventIds = try await handler.fetchEventsFromDatabaseWithIds()
        
        // Fetch all events with these IDs in a single query
        let descriptor = FetchDescriptor<QuiEvent>(predicate: #Predicate<QuiEvent> { event in
          eventIds.contains(event.id)
        })
        let fetchedEvents = try modelContext.fetch(descriptor)
        
        // Sort them in the same order as the IDs
        events = eventIds.compactMap { id in
          fetchedEvents.first { $0.id == id }
        }
        
        print("Watch App: Loaded \(events.count) events")
        
        // If no events and this is the first launch, show loading state
        if events.isEmpty && lastUpdateDate == Date.distantPast {
          isInitialFetching = true
          // Start monitoring for updates
          startMonitoringForUpdates()
        }
        
        // Note: Background refresh is handled by the main app's onAppear
        // to prevent conflicts and duplication
      } catch {
        print("Error loading events: \(error)")
      }
      
      isLoadingEvents = false
    }
  }
  
  private func refreshEvents() async {
    do {
      print("Watch App: Starting refresh...")
      let handler = QuiEventHandler(modelContainer: modelContext.container)
      try await handler.updateFromWeb(imageCache: imageCache)
      
      // Reload events after updating
      let eventIds = try await handler.fetchEventsFromDatabaseWithIds()
      
      // Fetch all events with these IDs in a single query
      let descriptor = FetchDescriptor<QuiEvent>(predicate: #Predicate<QuiEvent> { event in
        eventIds.contains(event.id)
      })
      let fetchedEvents = try modelContext.fetch(descriptor)
      
      // Sort them in the same order as the IDs
      events = eventIds.compactMap { id in
        fetchedEvents.first { $0.id == id }
      }
      
      print("Watch App: After refresh, loaded \(events.count) events")
    } catch {
      print("Error refreshing events: \(error)")
    }
  }
  
  private func reloadEvents() {
    Task {
      do {
        let handler = QuiEventHandler(modelContainer: modelContext.container)
        let eventIds = try await handler.fetchEventsFromDatabaseWithIds()
        
        // Fetch all events with these IDs in a single query
        let descriptor = FetchDescriptor<QuiEvent>(predicate: #Predicate<QuiEvent> { event in
          eventIds.contains(event.id)
        })
        let fetchedEvents = try modelContext.fetch(descriptor)
        
        // Sort them in the same order as the IDs
        events = eventIds.compactMap { id in
          fetchedEvents.first { $0.id == id }
        }
        
        print("Watch App: Reloaded \(events.count) events")
      } catch {
        print("Error reloading events: \(error)")
      }
    }
  }
  
  private func startMonitoringForUpdates() {
    // Check for updates every 2 seconds until we have events or timeout
    Task {
      var attempts = 0
      let maxAttempts = 30 // 60 seconds max
      
      while events.isEmpty && attempts < maxAttempts && isInitialFetching {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
          let handler = QuiEventHandler(modelContainer: modelContext.container)
          let eventIds = try await handler.fetchEventsFromDatabaseWithIds()
          
          // Fetch all events with these IDs in a single query
          let descriptor = FetchDescriptor<QuiEvent>(predicate: #Predicate<QuiEvent> { event in
            eventIds.contains(event.id)
          })
          let fetchedEvents = try modelContext.fetch(descriptor)
          
          // Sort them in the same order as the IDs
          let newEvents = eventIds.compactMap { id in
            fetchedEvents.first { $0.id == id }
          }
          
          await MainActor.run {
            events = newEvents
          }
        } catch {
          print("Error monitoring for updates: \(error)")
        }
        
        attempts += 1
      }
      
      await MainActor.run {
        isInitialFetching = false
      }
    }
  }
  
  var body: some View {
    NavigationStack {
      VStack {
        if eventsForSelectedDate.isEmpty {
          if isInitialFetching {
            VStack {
              ProgressView()
                .scaleEffect(1.5)
              Text("Loading events...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
          } else {
            NoEventWatch(
              nextEvent: nextEventAfter,
              selectedDate: $selectedDate
            )
          }
        } else {
          TabView(selection: $currentEvent) {
            ForEach(eventsForSelectedDate) { event in
              EventCardWatch(event: event)
                .tag(event)
            }
          }
          .onAppear {
            if currentEvent == nil {
              currentEvent = eventsForSelectedDate.first
            }
          }
          .tabViewStyle(.page)
        }
      }
      .ignoresSafeArea([])
      .onAppear {
        loadEvents()
      }
      .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationDidBecomeActiveNotification)) { _ in
        reloadEvents()
      }
      .onChange(of: selectedDate) {
        currentEvent = eventsForSelectedDate.first
      }
      .sheet(isPresented: $showEventList) {
        EventsList(selectedDate: $selectedDate)
      }
      .sheet(isPresented: $showInfo) {
        InfoView()
      }
      .background(
        ZStack {
          Image("backdrop")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4)
            .saturation(0)
            .ignoresSafeArea()
          
          Rectangle()
            .foregroundStyle(.thinMaterial)
            .ignoresSafeArea()
          
          LinearGradient(
            colors: [
              currentEvent?.eventLocation.backgroundColor ?? Color.noEvent,
              Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea()
          .opacity(0.4)
        }
      )
      .animation(.default, value: currentEvent)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            showDatePicker.toggle()
          } label: {
            Label("Calendar", systemImage: "calendar")
          }
          .sheet(isPresented: $showDatePicker) {
            DateChooser(
              selectedDate: $selectedDate,
              showDatePicker: $showDatePicker,
              currentEvent: currentEvent
            )
          }
        }
          
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showEventList.toggle()
          } label: {
            Label("List", systemImage: "list.triangle")
          }
        }
        
        ToolbarItemGroup(placement: .bottomBar) {
          HStack {
            Button {
              showInfo.toggle()
            } label: {
              Image(systemName: "ellipsis")
            }
            
            Spacer()
            
            if events.isEmpty {
              Button {
                Task {
                  await refreshEvents()
                }
              } label: {
                Image(systemName: "arrow.clockwise")
              }
            }
          }
        }
        
//        ToolbarItemGroup(placement: .bottomBar) {
//          Button {
//            deleteAllEvents()
//          } label: {
//            Label("Delete Fake Events", systemImage: "trash")
//          }
//          
//          Spacer()
//          
//          Button {
//            addFakeEvent()
//          } label: {
//            Label("Add Fake Event", systemImage: "plus")
//          }
//        }
      }
      .navigationTitle(navigationTitle)
#if os(iOS)
      .toolbarTitleDisplayMode(.inlineLarge)
#endif
    }
  }
  
  private func deleteAllEvents() {
    events.forEach { event in
      modelContext.delete(event)
    }
    
    try? modelContext.save()
    
    currentEvent = nil
    WidgetCenter.shared.reloadAllTimelines()
  }
  
  private func getRandomEventType() -> EventType {
    let randomIndex = Int.random(in: 0..<EventType.allCases.count)
    return EventType.allCases[randomIndex]
  }
}

#Preview {
  ContentView()
    .modelContainer(for: QuiEvent.self, inMemory: true)
}
