

import Foundation
import Network
import Combine

@MainActor
@Observable
class NetworkManager {

    @ObservationIgnored static let shared = NetworkManager()

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "NetworkMonitor")

    var isConnected: Bool = false

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    func checkConnection() -> Bool {
        let path = monitor.currentPath
        return path.status == .satisfied
    }

    deinit {
        monitor.cancel()
    }
}

