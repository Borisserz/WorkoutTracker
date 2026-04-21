

import Foundation
import Network
import Combine

class NetworkManager: ObservableObject {

    static let shared = NetworkManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = false

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
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

