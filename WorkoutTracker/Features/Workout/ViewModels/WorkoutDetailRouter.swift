//
//  WorkoutDetailRouter.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//

internal import SwiftUI
import Observation

@Observable
@MainActor
final class WorkoutDetailRouter {
    var activeDestination: DetailDestination? = nil
    var snackbarMessage: LocalizedStringKey? = nil
    
    // ✅ ДОБАВЛЕНО: Хранилище для картинок/данных Share Sheet
    var shareItems: [Any] = []
    
    // Actions for Snackbar
    @ObservationIgnored var snackbarCommitAction: (() -> Void)?
    @ObservationIgnored var snackbarUndoAction: (() -> Void)?
    @ObservationIgnored var snackbarTask: Task<Void, Never>?
    
    var activeSheet: DetailDestination? {
        get { activeDestination?.isSheet == true ? activeDestination : nil }
        set { if newValue == nil { activeDestination = nil } else { activeDestination = newValue } }
    }
    
    var activeFullScreen: DetailDestination? {
        get { activeDestination?.isFullScreen == true ? activeDestination : nil }
        set { if newValue == nil { activeDestination = nil } else { activeDestination = newValue } }
    }
    
    var isShowingEmptyAlert: Bool {
        get { activeDestination == .emptyWorkoutAlert }
        set { if !newValue && activeDestination == .emptyWorkoutAlert { activeDestination = nil } }
    }
    
    func showSnackbar(message: LocalizedStringKey, onCommit: @escaping () -> Void, onUndo: @escaping () -> Void) {
            withAnimation { self.snackbarMessage = message }
            self.snackbarCommitAction = onCommit
            self.snackbarUndoAction = onUndo
            
            snackbarTask?.cancel()
            snackbarTask = Task {
                // ✅ Рефакторинг: Читаемый и безопасный синтаксис
                try? await Task.sleep(for: .seconds(3.5))
                if !Task.isCancelled { self.commitSnackbar() }
            }
        }
    
    func commitSnackbar() {
        guard snackbarMessage != nil else { return }
        snackbarCommitAction?()
        withAnimation { snackbarMessage = nil }
        resetSnackbar()
    }
    
    func undoAction() {
        snackbarTask?.cancel()
        withAnimation { snackbarUndoAction?(); snackbarMessage = nil }
        resetSnackbar()
    }
    
    private func resetSnackbar() {
        snackbarTask?.cancel()
        snackbarCommitAction = nil
        snackbarUndoAction = nil
        snackbarTask = nil
    }
}
