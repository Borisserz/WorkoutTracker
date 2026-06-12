internal import SwiftUI

struct RestTimerView: View {
    @Environment(RestTimerManager.self) var timerManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    // PiP position states
    @State private var currentPosition: CGPoint = CGPoint(
        x: UIScreen.main.bounds.width - 52, // snapped to right by default (64px wide/2 + 20px padding)
        y: UIScreen.main.bounds.height - 250
    )
    @State private var dragOffset: CGSize = .zero
    @State private var isExpanded: Bool = false
    @State private var isPulsing = false

    var body: some View {
        if timerManager.isRestTimerActive {
            ZStack {
                if isExpanded {
                    expandedControlsView
                } else {
                    collapsedCircleView
                }
            }
            .position(
                x: currentPosition.x + dragOffset.width,
                y: currentPosition.y + dragOffset.height
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
            .onChange(of: timerManager.restTimerFinished) { _, finished in
                if finished {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
        }
    }

    private var collapsedCircleView: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded = true
            }
        } label: {
            ZStack {
                // Glass background
                Circle()
                    .fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.9)))
                    .frame(width: 64, height: 64)
                
                // Neon glow outline
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent,
                                timerManager.restTimerFinished ? Color.green.opacity(0.5) : .purple
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 64, height: 64)
                
                // Ring Progress
                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(
                        timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.progress)
                
                // Center text
                if timerManager.restTimerFinished {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                        .symbolEffect(.bounce, value: timerManager.restTimerFinished)
                } else {
                    Text(timeStringShort(time: timerManager.restTimeRemaining))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .contentTransition(.numericText())
                }
            }
            .shadow(
                color: (timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent)
                    .opacity(isPulsing ? 0.6 : 0.3),
                radius: isPulsing ? 12 : 6
            )
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .scaleEffect(isExpanded ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height
                    let radius: CGFloat = 32
                    let padding: CGFloat = 16
                    
                    var newX = currentPosition.x + value.translation.width
                    var newY = currentPosition.y + value.translation.height
                    
                    // Allow free positioning, keeping it within safe boundaries
                    newX = max(radius + padding, min(screenWidth - radius - padding, newX))
                    newY = max(100, min(screenHeight - 150, newY))
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        currentPosition = CGPoint(x: newX, y: newY)
                        dragOffset = .zero
                    }
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation {
                    timerManager.stopRestTimer()
                }
            }
        )
    }

    private var expandedControlsView: some View {
        HStack(spacing: 12) {
            if !timerManager.restTimerFinished {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    timerManager.subtractRestTime(15)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 36, height: 36)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(timerManager.progress))
                            .stroke(
                                timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent,
                                style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: timerManager.progress)
                        
                        if timerManager.restTimerFinished {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timerManager.restTimerFinished ? "Done" : timeStringLong(time: timerManager.restTimeRemaining))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text(timerManager.restTimerFinished ? "Tap to close" : "Resting")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)
            
            if !timerManager.restTimerFinished {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    timerManager.addRestTime(15)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 36, height: 36)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    timerManager.stopRestTimer()
                }
            } label: {
                Image(systemName: timerManager.restTimerFinished ? "xmark" : "forward.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(timerManager.restTimerFinished ? .white : themeManager.current.background)
                    .frame(width: 36, height: 36)
                    .background(timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.95)))
        .cornerRadius(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    LinearGradient(
                        colors: [
                            timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent,
                            .purple.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: (timerManager.restTimerFinished ? Color.green : themeManager.current.primaryAccent).opacity(0.35),
            radius: 8,
            y: 4
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height
                    let halfWidth: CGFloat = 100 // half width of expanded controls
                    let padding: CGFloat = 16
                    
                    var newX = currentPosition.x + value.translation.width
                    var newY = currentPosition.y + value.translation.height
                    
                    // Allow free positioning, keeping it within safe boundaries
                    newX = max(halfWidth + padding, min(screenWidth - halfWidth - padding, newX))
                    newY = max(100, min(screenHeight - 150, newY))
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        currentPosition = CGPoint(x: newX, y: newY)
                        dragOffset = .zero
                    }
                }
        )
    }

    private func timeStringShort(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)"
        }
    }

    private func timeStringLong(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
