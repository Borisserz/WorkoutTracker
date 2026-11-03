import Foundation
import SwiftData

/// Top finished sessions by stored strength volume, independent of the History page window.
enum HistoryBestSessionQuery {
    static let limit = 6

    static func descriptor() -> FetchDescriptor<Workout> {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil },
            sortBy: [SortDescriptor(\.totalStrengthVolume, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }
}
