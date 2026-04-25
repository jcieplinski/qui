//
//  Constants.swift
//  qui
//
//  Created by Joe Cieplinski on 5/10/25.
//

import Foundation

enum Constants {
  static let eventsAPIEndpoint = "https://quievents.com/events.json"
  static let specialEventsAPIEndpoint = "https://quievents.com/specialEvents.json"
  static let appGroup = "group.com.joecieplinski.qui"
}

enum DefaultsKey {
  static let lastFetch = "lastFetch"
  static let widgetEventIndex = "widgetEventIndex"
  static let widgetEventDate = "widgetEventDate"
}
