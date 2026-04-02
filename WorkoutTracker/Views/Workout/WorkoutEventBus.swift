//
//  WorkoutEventBus.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

//
//  WorkoutEventBus.swift
//  WorkoutTracker
//

import Foundation

/// Потокобезопасная шина событий для уведомления независимых компонентов
/// об изменениях в данных (создание, удаление, завершение тренировки).
actor WorkoutEventBus {
    static let shared = WorkoutEventBus()
    
    private var continuations = [UUID: AsyncStream<Void>.Continuation]()
    
    /// Асинхронный поток событий, на который могут подписываться ViewModels
    var updates: AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }
    
    /// Триггер обновления. Вызывается после любых мутаций базы данных.
    func triggerUpdate() {
        for continuation in continuations.values {
            continuation.yield(())
        }
    }
    
    private func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
