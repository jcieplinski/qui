//
//  Dongles.swift
//  Mission Rock Events
//
//  Created by Joe Cieplinski on 5/7/25.
//

import Foundation

extension Date {
  // Pacific timezone identifier
  private static let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles")!
  
  func isToday() -> Bool {
    // Use Pacific timezone for date comparison
    var pacificCalendar = Calendar.current
    pacificCalendar.timeZone = Self.pacificTimeZone
    
    let nowInPacific = Date().convertedToPacificTime()
    let selfInPacific = self.convertedToPacificTime()
    
    return pacificCalendar.startOfDay(for: nowInPacific) == pacificCalendar.startOfDay(for: selfInPacific)
  }
  
  func isYesterday() -> Bool {
    var pacificCalendar = Calendar.current
    pacificCalendar.timeZone = Self.pacificTimeZone
    
    guard let yesterday = pacificCalendar.date(byAdding: .day, value: -1, to: Date().convertedToPacificTime()) else { return false }
    
    let selfInPacific = self.convertedToPacificTime()
    return pacificCalendar.startOfDay(for: yesterday) == pacificCalendar.startOfDay(for: selfInPacific)
  }
  
  static func yesterday() -> Date? {
    var pacificCalendar = Calendar.current
    pacificCalendar.timeZone = pacificTimeZone
    
    return pacificCalendar.date(byAdding: .day, value: -1, to: Date().convertedToPacificTime())
  }
  
  static func dateStringToDate(dateString: String, timeString: String) -> (date: Date, timeTBD: Bool) {
    var timeTBD: Bool = false
    let dateFormatter = DateFormatter()
    
    // Force Pacific timezone for all date parsing
    dateFormatter.timeZone = pacificTimeZone
    
    if !timeString.contains(":") {
      timeTBD = true
      dateFormatter.dateFormat = "YYYY-MM-dd"
      let pacificDate = dateFormatter.date(from: dateString) ?? Date()
      return (date: pacificDate, timeTBD: timeTBD)
    } else {
      dateFormatter.dateFormat = "YYYY-MM-dd HH:mm"
      let pacificDate = dateFormatter.date(from: "\(dateString) \(timeString)") ?? Date()
      return (date: pacificDate, timeTBD: timeTBD)
    }
  }
  
  static func dateToStringDateStringTime(date: Date) -> (stringDate: String, stringTime: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "YYYY-MM-dd HH:mm"
    
    // Force Pacific timezone for all date formatting
    dateFormatter.timeZone = pacificTimeZone
    
    let string = dateFormatter.string(from: date)
    let split = string.split(separator: " ")
    
    return (stringDate: String(split[0]), stringTime: String(split[1]))
  }
  
  // Helper method to convert any date to Pacific time
  func convertedToPacificTime() -> Date {
    var pacificCalendar = Calendar.current
    pacificCalendar.timeZone = Self.pacificTimeZone
    
    // Get components in Pacific time
    let components = pacificCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
    
    // Create a new date in Pacific time
    return pacificCalendar.date(from: components) ?? self
  }
  
  // Helper method to get start of day in Pacific time
  func startOfDayInPacificTime() -> Date {
    var pacificCalendar = Calendar.current
    pacificCalendar.timeZone = Self.pacificTimeZone
    
    return pacificCalendar.startOfDay(for: self)
  }
}
