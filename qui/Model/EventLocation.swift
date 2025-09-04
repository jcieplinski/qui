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
    case .other:
      return .otherRed
    }
  }
  
  var textColor: Color {
    switch self {
    case .oraclePark, .ferryBuilding:
      return .black
    case .chaseCenter, .pier48, .chinaBasin:
      return .white
    case .other:
      return .white
    }
  }
}
