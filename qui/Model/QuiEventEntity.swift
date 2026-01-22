//
//  QuiEventEntity.swift
//  qui
//
//  Created by Joe Cieplinski on 5/8/25.
//

import SwiftData
import AppIntents

struct QuiEventEntity: Identifiable, AppEntity {
  static let defaultQuery = QuiEventQuery()
  
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event"
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)")
  }
  
  let id: UUID
  let title: String
  let subtitle: String?
  let type: String
  let location: String
  let date: Date
  let performers: String?
  let url: String?
  let imageURL: String?
  let source: String
  
  internal init(
    id: UUID,
    title: String,
    subtitle: String?,
    type: String,
    location: String,
    date: Date,
    performers: String?,
    url: String?,
    imageURL: String?,
    source: String
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.type = type
    self.location = location
    self.date = date
    self.performers = performers
    self.url = url
    self.imageURL = imageURL
    self.source = source
  }
  
  init(event: QuiEvent) {
    self.id = event.id
    self.title = event.title
    self.subtitle = event.subtitle
    self.type = event.type
    self.location = event.location
    self.date = event.date
    self.performers = event.performers
    self.url = event.url
    self.imageURL = event.imageURL
    self.source = event.source
  }
  
  var eventLocation: EventLocation {
    return EventLocation(text: location) ?? .other
  }
}
