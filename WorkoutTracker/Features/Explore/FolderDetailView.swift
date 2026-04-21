

internal import SwiftUI

struct FolderDetailView: View {
    let folderTitle: LocalizedStringKey
    let folderName: String?

    let items: [CarouselItemType]

    let onItemTapped: (CarouselItemType) -> Void
    let onEdit: ((WorkoutPreset) -> Void)?
    let onDuplicate: ((WorkoutPreset) -> Void)?
    let onDelete: ((CarouselItemType) -> Void)?

    @Environment(PresetService.self) private var presetService
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.id) { item in
                    PremiumCarouselCardView(
                        item: item,
                        onTap: { onItemTapped(item) },
                        onEdit: onEdit,
                        onDuplicate: onDuplicate,
                        onDelete: onDelete
                    )
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(folderTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let fName = folderName, !fName.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(folderName ?? "Folder")?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Routines", role: .destructive) {
                deleteEntireFolder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this entire program? This action cannot be undone.")
        }
    }

    private func deleteEntireFolder() {
        guard let fName = folderName else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        Task {
            await presetService.deleteFolder(named: fName)
            dismiss()
        }
    }
}
