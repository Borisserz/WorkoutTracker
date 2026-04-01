//
//  SupersetCardView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
enum PRLevel {
    case bronze, silver, gold, diamond
    
    // Твои старые свойства
    var angularColors: [Color] {
        switch self {
        case .bronze: return [.brown, .orange, .brown, .orange, .brown]
        case .silver: return [.gray, .white, .gray, .white, .gray]
        case .gold: return [.yellow, .orange, .yellow, .orange, .yellow]
        case .diamond: return [.cyan, .white, .purple, .blue, .cyan]
        }
    }
    
    var title: String {
        switch self {
        case .bronze: return String(localized: "Bronze Record!")
        case .silver: return String(localized: "Silver Record!")
        case .gold: return String(localized: "Gold Record!")
        case .diamond: return String(localized: "Diamond Record!")
        }
    }
    
    var rank: Int {
        switch self {
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 4
        }
    }
}

struct PRCelebrationView: View {
    let prLevel: PRLevel
    let onClose: () -> Void
    
    @State private var isAnimatingPR = false
    @State private var shareItem: SharedImageWrapper?
    
    var body: some View {
        ZStack {
            Color.clear.background(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]), center: .center, startRadius: 10, endRadius: 60))
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .strokeBorder(AngularGradient(gradient: Gradient(colors: prLevel.angularColors), center: .center), lineWidth: 12)
                        .frame(width: 120, height: 120)
                        .shadow(color: prLevel.angularColors.first!.opacity(0.8), radius: isAnimatingPR ? 15 : 5)
                    
                    Image(systemName: prLevel == .diamond ? "sparkles" : "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient(colors: prLevel.angularColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .scaleEffect(isAnimatingPR ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimatingPR)
                
                VStack(spacing: 4) {
                    Text(LocalizedStringKey(prLevel.title)).font(.title2).bold().foregroundColor(.white)
                    Text(String(localized: "New Personal Best!")).font(.subheadline).foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.6)).overlay(Capsule().stroke(LinearGradient(colors: prLevel.angularColors, startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)))
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.7)) }.padding(25)
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                Button { share() } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(LocalizedStringKey("Share Result"))
                    }
                    .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: prLevel.angularColors, startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16).shadow(radius: 10)
                }
                .padding(.horizontal, 30).padding(.bottom, 40)
            }
        }
        .onAppear { isAnimatingPR = true }
        .onDisappear { isAnimatingPR = false }
        .sheet(item: $shareItem) { item in ActivityViewController(activityItems: [item.image]) }
    }
    
    @MainActor
    private func share() {
        let renderer = ImageRenderer(content: MilestoneShareCard(title: LocalizedStringKey("New Personal Best!"), subtitle: LocalizedStringKey(prLevel.title), descriptionText: LocalizedStringKey("Hard work pays off!"), icon: prLevel == .diamond ? "sparkles" : "trophy.fill", colors: prLevel.angularColors))
        renderer.scale = 3.0
        if let image = renderer.uiImage { shareItem = SharedImageWrapper(image: image) }
    }
}

struct SupersetCardView: View {
    @Bindable var superset: Exercise
    @Environment(\.modelContext) private var context
    @Environment(WorkoutViewModel.self) var viewModel
    
    var currentWorkoutId: UUID
    var onDelete: () -> Void
    var isWorkoutCompleted: Bool = false
    
    @Binding var isExpanded: Bool
    var onExerciseFinished: (() -> Void)? = nil
    var isCurrentExercise: Bool = false
    
    var onPRSet: ((PRLevel) -> Void)? = nil
    var onSetCompleted: ((WorkoutSet, Bool, String) -> Void)? = nil // <-- ДОБАВЛЕНО
    
    @State private var showEffortSheet = false
    
    private var isActiveExercise: Bool { isCurrentExercise && !superset.isCompleted }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                if isExpanded {
                    exerciseListView
                    finishButton
                } else {
                    collapsedInfoSection
                }
            }
            .padding()
            .background(isActiveExercise ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActiveExercise ? Color.blue.opacity(0.5) : Color.clear, lineWidth: isActiveExercise ? 2 : 0))
            .shadow(color: isActiveExercise ? Color.blue.opacity(0.2) : Color.clear, radius: isActiveExercise ? 8 : 0, x: 0, y: 2)
        }
        .sheet(isPresented: $showEffortSheet, onDismiss: { if superset.isCompleted { onExerciseFinished?() } }) {
            EffortInputView(effort: $superset.effort)
        }
    }
    
    var headerView: some View {
        HStack {
            Image(systemName: "line.3.horizontal").foregroundColor(.gray).font(.caption).frame(width: 20, height: 20)
            HStack {
                Image(systemName: "link").foregroundColor(.purple)
                Text(String(localized: "Superset")).font(.headline).foregroundColor(.purple)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { onDelete() } label: { Label(String(localized: "Remove Superset"), systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").foregroundColor(.gray).padding(10)
            }
            .highPriorityGesture(TapGesture().onEnded { })
        }
        .padding(.bottom, 10).contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }
    }
    
    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text(String(localized: "Tap to expand")).font(.caption).foregroundColor(.secondary).italic()
            Spacer()
        }.padding(.vertical, 8)
    }
    
    var exerciseListView: some View {
        // Используем индексы для корректной работы
        ForEach(superset.subExercises.indices, id: \.self) { index in
            let isLast = index == superset.subExercises.count - 1
            
            VStack(spacing: 0) {
                // ИСПРАВЛЕНИЕ: Передаем объект без знака '$'
                ExerciseCardView(
                    exercise: superset.subExercises[index],
                    currentWorkoutId: currentWorkoutId,
                    onDelete: {
                        withAnimation {
                            viewModel.removeSubExercise(superset.subExercises[index], from: superset)
                        }
                    },
                    isEmbeddedInSuperset: true,
                    isWorkoutCompleted: isWorkoutCompleted,
                    isExpanded: .constant(true),
                    onExerciseFinished: onExerciseFinished,
                    isCurrentExercise: false,
                    onPRSet: onPRSet,
                    onSetCompleted: onSetCompleted
                )
                .background(Color.clear).shadow(color: .clear, radius: 0).padding(.horizontal, -16).padding(.vertical, -8)
                
                if !isLast { Divider().padding(.leading, 16).padding(.vertical, 8) }
            }
        }
    }
    var finishButton: some View {
            Button(action: {
                onExerciseFinished?() 
            }) {
                Text(String(localized: "Finish Superset")).font(.subheadline).bold().frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.green.opacity(0.1)).foregroundColor(.green).cornerRadius(8)
        }
        .padding(.top, 12).buttonStyle(BorderlessButtonStyle()).disabled(superset.isCompleted || isWorkoutCompleted)
    }
}
