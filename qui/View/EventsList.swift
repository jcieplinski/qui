//
//  EventsList.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/7/25.
//

import SwiftUI
import SwiftData
import EventKit

struct EventsList: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Environment(\.imageCache) private var imageCache
  @State private var events: [QuiEvent] = []
  
  @State private var ekEvent: EKEvent?
  @State private var showEventEditor: Bool = false
  @State private var searchText: String = ""
  @State private var filteredEvents: [QuiEvent] = []
  @State private var isRefreshing: Bool = false
  @AppStorage("lastUpdateDate") private var lastUpdateDate: Date = Date.distantPast
  
  @Binding var selectedDate: Date
  
  let eventStore = EKEventStore()
  var currentEvent: QuiEvent?
  
  var lastUpdateText: String {
    if lastUpdateDate == Date.distantPast {
      return "Last Updated: Never"
    } else {
      return "Last Updated: \(lastUpdateDate.formatted(date: .abbreviated, time: .omitted))"
    }
  }
  
  private func updateFilteredEvents() {
    if searchText.isEmpty {
      filteredEvents = events
    } else {
      filteredEvents = events.filter { event in
        event.title.localizedCaseInsensitiveContains(searchText) ||
        event.location.localizedCaseInsensitiveContains(searchText) ||
        event.type.localizedCaseInsensitiveContains(searchText)
      }
    }
  }
  
  private func loadEvents() async {
    do {
      let handler = QuiEventHandler(modelContainer: modelContext.container)
      let eventIds = try await handler.fetchEventsFromDatabaseWithIds()
      
      // Fetch all events with these IDs in a single query
      let descriptor = FetchDescriptor<QuiEvent>(predicate: #Predicate<QuiEvent> { event in
        eventIds.contains(event.id)
      })
      let fetchedEvents = try modelContext.fetch(descriptor)
      
      // Sort them in the same order as the IDs
      let allEvents = eventIds.compactMap { id in
        fetchedEvents.first { $0.id == id }
      }
      
      // Filter out past events (only keep today and future events) using Pacific timezone
      var pacificCalendar = Calendar.current
      pacificCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
      let today = pacificCalendar.startOfDay(for: Date().convertedToPacificTime())
      
      events = allEvents.filter { event in
        pacificCalendar.startOfDay(for: event.date) >= today
      }
      
      updateFilteredEvents()
    } catch {
      print("Error loading events: \(error)")
    }
  }
  
  private func refreshEvents() async {
    isRefreshing = true
    
    do {
      let handler = QuiEventHandler(modelContainer: modelContext.container)
      try await handler.updateFromWeb(imageCache: imageCache)
      
      // Update lastUpdateDate
      await MainActor.run {
        lastUpdateDate = Date()
      }
      
      // Reload events after updating
      await loadEvents()
    } catch {
      print("Error refreshing events: \(error)")
    }
    
    isRefreshing = false
  }
  
  var body: some View {
    NavigationStack {
      if filteredEvents.isEmpty {
        VStack {
          Spacer()
          
          Label("No Events", systemImage: "calendar")
          
          Spacer()
        }
      }
      
      List(filteredEvents) { event in
        Button {
          selectedDate = event.date
          dismiss()
        } label: {
          HStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: event.imageURL ?? "")) { image in
              image
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            } placeholder: {
              ProgressView()
                .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading) {
              Text(event.title)
                .font(.headline)
              if let subtitle = event.subtitle {
                Text(subtitle)
                  .font(.subheadline)
              }
              Text(event.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
              Text(event.location)
                .font(.caption)
                .padding(.top, 2)
            }
            
#if os(iOS)
            Spacer()
            
            Button {
              createEvent(event: event)
            } label: {
              Image(systemName: "calendar.badge.plus")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
#endif
          }
        }
        .listRowBackground(Rectangle().foregroundStyle(.ultraThinMaterial))
      }
      .searchable(text: $searchText, placement: .automatic)
      .onChange(of: searchText) { _, _ in
        updateFilteredEvents()
      }
      .onAppear {
        Task {
          await loadEvents()
        }
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollContentBackground(.hidden)
      .navigationTitle("All Events")
      .navigationBarTitleDisplayMode(.inline)
#if os(iOS)
      .sheet(isPresented: $showEventEditor, onDismiss: {
        ekEvent = nil
      }, content: {
        EventEditView(eventStore: eventStore, event: $ekEvent)
      })
      .toolbar {
#if DEBUG
        ToolbarItem(placement: .topBarLeading) {
          Button {
            Task {
              await refreshEvents()
            }
          } label: {
            if isRefreshing {
              ProgressView()
            } else {
              Image(systemName: "arrow.clockwise")
            }
          }
          .disabled(isRefreshing)
        }
#endif
        
        ToolbarItem(placement: .topBarTrailing) {
          if #available(iOS 26.0, *) {
            Button(role: .confirm) {
              dismiss()
            }
            .tint(currentEvent != nil ? currentEvent?.eventLocation.backgroundColor ?? .primary : .primary)
          } else {
            Button(action: { dismiss() }) {
              Image(systemName: "xmark")
            }
            .accessibilityLabel("Done")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        HStack {
          Spacer()
          Text(lastUpdateText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
          Spacer()
        }
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
      }
#endif
    }
  }
  
  private func createEvent(event: QuiEvent) {
    ekEvent = EKEvent(eventStore: eventStore)
    ekEvent?.title = event.title
    ekEvent?.startDate = event.date
    ekEvent?.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: event.date) ?? event.date
    ekEvent?.location = event.location
    showEventEditor = true
  }
}

#Preview {
  @Previewable @State var selectedDate: Date = Date()
  EventsList(selectedDate: $selectedDate)
    .modelContainer(for: QuiEvent.self, inMemory: true)
}
