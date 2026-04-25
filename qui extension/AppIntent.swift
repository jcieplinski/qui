//
//  AppIntent.swift
//  Mission Rock Events Widget Extension
//
//  Created by Joe Cieplinski on 5/8/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Qui Events" }
    static var description: IntentDescription { "Show today's events." }
}

struct NextEventIntent: AppIntent {
    static var title: LocalizedStringResource { "Next Event" }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.appGroup
        let current = defaults.integer(forKey: DefaultsKey.widgetEventIndex)
        defaults.set(current + 1, forKey: DefaultsKey.widgetEventIndex)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct PreviousEventIntent: AppIntent {
    static var title: LocalizedStringResource { "Previous Event" }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.appGroup
        let current = defaults.integer(forKey: DefaultsKey.widgetEventIndex)
        defaults.set(max(0, current - 1), forKey: DefaultsKey.widgetEventIndex)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
