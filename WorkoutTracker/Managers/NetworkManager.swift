//
//  NetworkManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 28.12.25.
//
//  Менеджер для проверки интернет-соединения.
//  Использует Network framework для мониторинга доступности сети.
//

import Foundation
import Network
import Combine

class NetworkManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = NetworkManager()
    
    // MARK: - Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = false
    
    // MARK: - Init
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Запускает мониторинг сетевого соединения
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Проверяет доступность интернет-соединения синхронно
    /// - Returns: true если есть интернет-соединение, false в противном случае
    func checkConnection() -> Bool {
        let path = monitor.currentPath
        return path.status == .satisfied
    }
    
    /// Останавливает мониторинг (вызывается при деинициализации)
    deinit {
        monitor.cancel()
    }
}

