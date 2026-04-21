

internal import SwiftUI
import Combine
import Observation

@Observable
@MainActor
final class SearchDebouncer {
    var inputText: String = "" {
        didSet {
            searchSubject.send(inputText)
        }
    }

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
