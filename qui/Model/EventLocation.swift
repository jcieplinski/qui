//
//  EventLocation.swift
//  qui
//
//  Created by Joe Cieplinski on 5/8/25.
//

import SwiftUI

enum EventLocation: String, Codable {
  case oraclePark
  case chaseCenter
  case ferryBuilding
  case chinaBasin
  case pier48
  case bigTopOraclePark
  case thriveCity
  case other
  
  init?(text: String) {
    switch text {
    case "Oracle Park":
      self = .oraclePark
    case "Chase Center":
      self = .chaseCenter
    case "Ferry Building":
      self = .ferryBuilding
    case "China Basin Park":
      self = .chinaBasin
    case "Pier 48":
      self = .pier48
    case "Under The Big Top, Oracle Park Lot A":
      self = .bigTopOraclePark
    case "Thrive City":
      self = .thriveCity
    default:
      self = .other
    }
  }
  
  var title: String {
    switch self {
    case .oraclePark:
      return "Oracle Park"
    case .chaseCenter:
      return "Chase Center"
    case .ferryBuilding:
      return "Ferry Building"
    case .chinaBasin:
      return "China Basin Park"
    case .pier48:
      return "Pier 48"
    case .bigTopOraclePark:
      return "Under The Big Top, Oracle Park Lot A"
    case .thriveCity:
      return "Thrive City"
    case .other:
      return "Other"
    }
  }
  
  var backgroundColor: Color {
    switch self {
    case .oraclePark:
      return .oracleOrange
    case .chaseCenter:
      return .chaseBlue
    case .ferryBuilding:
      return .ferryGrey
    case .chinaBasin:
      return .chinaBasinGreen
    case .pier48:
      return .pier48Blue
    case .bigTopOraclePark:
      return .bigTop
    case .thriveCity:
      return .chaseBlue
    case .other:
      return .otherRed
    }
  }
  
  var textColor: Color {
    switch self {
    case .oraclePark, .ferryBuilding:
      return .black
    case .chaseCenter, .pier48, .chinaBasin, .bigTopOraclePark, .thriveCity:
      return .white
    case .other:
      return .white
    }
  }
}
