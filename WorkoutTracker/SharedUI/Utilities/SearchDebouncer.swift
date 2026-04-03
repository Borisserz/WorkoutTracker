//
//  SearchDebouncer.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//
internal import SwiftUI
import Combine
import Observation

/// Универсальный класс для реактивной задержки ввода (Debounce) без использования Task.sleep
@Observable
@MainActor
final class SearchDebouncer {
    var inputText: String = "" {
        didSet {
            searchSubject.send(inputText)
        }
    }
    
    /// Дебаунснутый текст, на который должен реагировать UI/База данных
    var debouncedText: String = ""
    
    @ObservationIgnored
    private let searchSubject = PassthroughSubject<String, Never>()
    
    @ObservationIgnored
    private var cancellable: AnyCancellable?
    
    init(delay: TimeInterval = 0.3) {
        cancellable = searchSubject
            .debounce(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.debouncedText = text
            }
    }
}
