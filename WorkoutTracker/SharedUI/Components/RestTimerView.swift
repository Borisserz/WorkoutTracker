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
    @GestureState private var dragOffset: CGSize = .zero
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
            .position(x: currentPosition.x, y: currentPosition.y)
            .offset(x: dragOffset.width, y: dragOffset.height)
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
                    .fill(PastelTheme.cardSurface)
                    .frame(width: 64, height: 64)
                
                // Track outline
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 54, height: 54)
                
                // Hairline border
                Circle()
                    .stroke(
                        timerManager.restTimerFinished ? PastelTheme.pastelAmber.opacity(0.6) : PastelTheme.cardBorder,
                        lineWidth: 1
                    )
                    .frame(width: 64, height: 64)
                
                // Ring Progress
                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(
                        timerManager.restTimerFinished ? PastelTheme.pastelAmber : PastelTheme.pastelSage,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.progress)
                
                // Center text
                if timerManager.restTimerFinished {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(PastelTheme.pastelAmber)
                        .symbolEffect(.bounce, value: timerManager.restTimerFinished)
                } else {
                    Text(timeStringShort(time: timerManager.restTimeRemaining))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(PastelTheme.textPrimary)
                        .contentTransition(.numericText())
                }
            }
            .shadow(
                color: Color.black.opacity(0.35),
                radius: 10,
                y: 4
            )
            .scaleEffect(isPulsing ? 1.06 : 1.0)
            .scaleEffect(isExpanded ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
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
                    Text("-15")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
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
                            .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(timerManager.progress))
                            .stroke(
                                timerManager.restTimerFinished ? PastelTheme.pastelAmber : PastelTheme.pastelSage,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: timerManager.progress)
                        
                        if timerManager.restTimerFinished {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(PastelTheme.pastelAmber)
                        } else {
                            Image(systemName: "timer")
                                .font(.system(size: 11))
                                .foregroundColor(PastelTheme.textPrimary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timerManager.restTimerFinished ? "Готово" : timeStringLong(time: timerManager.restTimeRemaining))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(PastelTheme.textPrimary)
                        Text(timerManager.restTimerFinished ? "Нажмите для закрытия" : "Отдых")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(PastelTheme.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            if !timerManager.restTimerFinished {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    timerManager.addRestTime(15)
                } label: {
                    Text("+15")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(timerManager.restTimerFinished ? .white : PastelTheme.canvas)
                    .frame(width: 36, height: 36)
                    .background(timerManager.restTimerFinished ? PastelTheme.pastelAmber : PastelTheme.pastelSage)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(PastelTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    timerManager.restTimerFinished ? PastelTheme.pastelAmber.opacity(0.5) : PastelTheme.cardBorder,
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.35),
            radius: 12,
            y: 5
        )
        .gesture(
            DragGesture(coordinateSpace: .global)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
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
