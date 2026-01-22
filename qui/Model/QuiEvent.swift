//
//  QuiEvent.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/7/25.
//

import SwiftUI
import SwiftData

@Model
final class QuiEvent: Codable, Equatable {
  internal init(
    id: UUID,
    title: String,
    subtitle: String?,
    type: String,
    location: String,
    date: Date,
    timeTBD: Bool,
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
    self.timeTBD = timeTBD
    self.performers = performers
    self.url = url
    self.imageURL = imageURL
    self.source = source
  }
  
  var id: UUID
  var title: String
  var subtitle: String?
  var type: String
  var location: String
  var date: Date
  var timeTBD: Bool
  var performers: String?
  var url: String?
  var imageURL: String? = nil
  var source: String
  
  var eventType: EventType {
    return EventType(rawValue: type) ?? .other
  }
  
  var eventSource: EventSource {
    return EventSource(rawValue: source) ?? .other
  }
  
  var eventLocation: EventLocation {
    return EventLocation(text: location) ?? .other
  }
  
  // MARK: - Codable
  
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case subtitle
    case type
    case location
    case date
    case time
    case performers
    case url
    case imageURL = "image_url"
    case source
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let idString = try container.decode(String.self, forKey: .id)
    id = UUID(uuidString: idString) ?? UUID()
    title = try container.decode(String.self, forKey: .title)
    subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
    type = try container.decode(String.self, forKey: .type)
    location = try container.decode(String.self, forKey: .location)
    performers = try container.decodeIfPresent(String.self, forKey: .performers)
    url = try container.decodeIfPresent(String.self, forKey: .url)
    imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
    source = try container.decode(String.self, forKey: .source)
    
    let stringDate = try container.decode(String.self, forKey: .date)
    let stringTime = try container.decode(String.self, forKey: .time)
    
    let dateResult = Date.dateStringToDate(dateString: stringDate, timeString: stringTime)
    date = dateResult.date
    timeTBD = dateResult.timeTBD
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id.uuidString, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(subtitle, forKey: .subtitle)
    try container.encode(type, forKey: .type)
    try container.encode(location, forKey: .location)
    try container.encodeIfPresent(performers, forKey: .performers)
    try container.encodeIfPresent(url, forKey: .url)
    try container.encodeIfPresent(imageURL, forKey: .imageURL)
    try container.encode(source, forKey: .source)
    
    let stringDateTime = Date.dateToStringDateStringTime(date: date)
    try container.encode(stringDateTime.stringDate, forKey: .date)
    
    if timeTBD {
      try container.encode("TBD", forKey: .time)
    } else {
      try container.encode(stringDateTime.stringTime, forKey: .time)
    }
  }
  
  static var previewEvent: QuiEvent {
    return QuiEvent(
      id: UUID(),
      title: "SF Giants vs. Colorado Rockies",
      subtitle: "This would be where a subtitle goes",
      type: EventType.sports.rawValue,
      location: EventLocation.oraclePark.title,
      date: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date()) ?? Date(),
      timeTBD: false,
      performers: "SF Giants",
      url: "https://mlb.com/giants",
      imageURL: "https://seatgeekimages.com/matchup/v3_f9157faa/22/30/huge.jpg",
      source: "SeatGeek API"
    )
  }
  
  static var previewNextEvent: QuiEvent {
    return QuiEvent(
      id: UUID(),
      title: "SF Giants vs. Colorado Rockies",
      subtitle: "This would be where a subtitle goes",
      type: EventType.sports.rawValue,
      location: EventLocation.oraclePark.title,
      date: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date(timeIntervalSinceNow: 432000)) ?? Date(timeIntervalSinceNow: 432000),
      timeTBD: false,
      performers: "SF Giants",
      url: "https://mlb.com/giants",
      imageURL: "https://seatgeekimages.com/matchup/v3_f9157faa/22/30/huge.jpg",
      source: "SeatGeek API"
    )
  }
}
