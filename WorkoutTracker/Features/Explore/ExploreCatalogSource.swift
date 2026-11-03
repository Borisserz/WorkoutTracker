import Foundation

/// Live Firestore catalog wins. An empty server response shows the bundled samples.
enum ExploreCatalogSource {
    static func programs(
        remote: [WorkoutProgramDefinition],
        offline: [WorkoutProgramDefinition]
    ) -> [WorkoutProgramDefinition] {
        remote.isEmpty ? offline : remote
    }

    static func isOffline(remoteCount: Int) -> Bool {
        remoteCount == 0
    }
}
