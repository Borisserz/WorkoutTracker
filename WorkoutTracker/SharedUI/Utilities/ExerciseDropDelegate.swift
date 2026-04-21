internal import SwiftUI
internal import UniformTypeIdentifiers

struct ExerciseDropDelegate: DropDelegate {
    let item: Exercise
    @Binding var items: [Exercise]
    @Binding var draggedItem: Exercise?

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }

        if draggedItem.id == item.id { return }

        if let from = items.firstIndex(where: { $0.id == draggedItem.id }),
           let to = items.firstIndex(where: { $0.id == item.id }) {

            withAnimation {

                let fromOffset = IndexSet(integer: from)
                let toOffset = to > from ? to + 1 : to
                items.move(fromOffsets: fromOffset, toOffset: toOffset)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {

        self.draggedItem = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
