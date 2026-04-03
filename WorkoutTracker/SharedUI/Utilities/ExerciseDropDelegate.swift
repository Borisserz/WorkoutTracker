internal import SwiftUI
internal import UniformTypeIdentifiers

struct ExerciseDropDelegate: DropDelegate {
    let item: Exercise
    @Binding var items: [Exercise]
    @Binding var draggedItem: Exercise?

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        // Если элемент перетаскивается сам на себя — ничего не делаем
        if draggedItem.id == item.id { return }
        
        // Находим индексы откуда и куда
        if let from = items.firstIndex(where: { $0.id == draggedItem.id }),
           let to = items.firstIndex(where: { $0.id == item.id }) {
            
            // Анимированно меняем местами
            withAnimation {
                // Безопасное перемещение
                let fromOffset = IndexSet(integer: from)
                let toOffset = to > from ? to + 1 : to
                items.move(fromOffsets: fromOffset, toOffset: toOffset)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        // Сбрасываем перетаскиваемый элемент после завершения
        self.draggedItem = nil
        return true
    }
    
    // Визуальный эффект при перетаскивании (можно оставить пустым)
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
