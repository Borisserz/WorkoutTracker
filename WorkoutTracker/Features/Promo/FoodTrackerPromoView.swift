internal import SwiftUI
import CoreMotion

// MARK: - Motion Manager
@Observable
class PromoMotionManager {
    static let shared = PromoMotionManager()
    private let motionManager = CMMotionManager()
    
    var pitch: Double = 0.0
    var roll: Double = 0.0
    
    init() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                self?.pitch = motion.attitude.pitch
                self?.roll = motion.attitude.roll
            }
        }
    }
}

// MARK: - Promo Feature Item
struct PromoFeatureItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let description: String
    let color: Color
    let leftIcon: String
    let leftLabel: String
    let rightIcon: String
    let rightLabel: String
}

// MARK: - Food Tracker Promo View
struct FoodTrackerPromoView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex = 0
    @State private var motionManager = PromoMotionManager.shared
    
    private let features: [PromoFeatureItem] = [
        PromoFeatureItem(
            iconName: "sparkles",
            title: "AI Nutrition Coach",
            description: "Chat with your personal AI coach. Get macro advice, daily verdicts, and personalized health guidance.",
            color: .pink,
            leftIcon: "message.fill",
            leftLabel: "24/7 AI Chat",
            rightIcon: "brain.head.profile",
            rightLabel: "Macro Verdicts"
        ),
        PromoFeatureItem(
            iconName: "camera.viewfinder",
            title: "Smart Food Vision",
            description: "Simply snap a photo of your meal or scan a barcode. Our AI instantly calculates your calories, protein, fats, and carbs.",
            color: .orange,
            leftIcon: "camera.viewfinder",
            leftLabel: "Photo Scan",
            rightIcon: "barcode.viewfinder",
            rightLabel: "Barcode Scan"
        ),
        PromoFeatureItem(
            iconName: "frying.pan.fill",
            title: "AI Chef Studio",
            description: "Input ingredients from your fridge and get diet-matched recipes. Plus, use your camera so the AI can monitor and guide your cooking process!",
            color: .yellow,
            leftIcon: "frying.pan.fill",
            leftLabel: "Diet Recipes",
            rightIcon: "camera.fill",
            rightLabel: "Cook Monitor"
        ),
        PromoFeatureItem(
            iconName: "person.crop.circle.badge.clock",
            title: "Visual Progress",
            description: "Upload Before & After photos to visually compare your transformation and let AI analyze your physical progress.",
            color: .green,
            leftIcon: "photo.stack.fill",
            leftLabel: "Before & After",
            rightIcon: "chart.line.uptrend.xyaxis",
            rightLabel: "AI Analysis"
        ),
        PromoFeatureItem(
            iconName: "chart.bar.xaxis",
            title: "Intelligent Analytics",
            description: "Deep insights into your consistency and habits, featuring an AI Hydration Coach that optimizes your water and pH balance.",
            color: .cyan,
            leftIcon: "drop.fill",
            leftLabel: "Hydration Coach",
            rightIcon: "chart.bar.xaxis",
            rightLabel: "pH Balance"
        )
    ]
    
    var safeIndex: Int { max(0, min(currentIndex, features.count - 1)) }
    
    var body: some View {
        ZStack {
            PromoCosmicStarfieldView(themeColor: features[safeIndex].color, motion: motionManager)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                }
                
                Text("Meet Food Tracker")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: features[safeIndex].color.opacity(0.5), radius: 10, y: 5)
                    .padding(.top, 10)
                
                Text("Our new beautiful app is out!")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                ZStack {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<features.count, id: \.self) { index in
                            PromoParallax3DCard(
                                item: features[index],
                                activeIndex: currentIndex,
                                cardIndex: index,
                                totalCount: features.count,
                                motion: motionManager
                            )
                            .padding(.horizontal, 32)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    HStack {
                        if currentIndex > 0 {
                            Button(action: {
                                if currentIndex > 0 {
                                    withAnimation { currentIndex -= 1 }
                                    HapticManager.shared.impact(.light)
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 8)
                        } else {
                            Spacer().frame(width: 52)
                        }
                        
                        Spacer()
                        
                        if currentIndex < features.count - 1 {
                            Button(action: {
                                if currentIndex < features.count - 1 {
                                    withAnimation { currentIndex += 1 }
                                    HapticManager.shared.impact(.light)
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 8)
                        } else {
                            Spacer().frame(width: 52)
                        }
                    }
                }
                .frame(height: 520)
                
                Spacer()
                
                PromoCosmicContinueButton(
                    title: "Download Food Tracker",
                    themeColor: features[safeIndex].color
                ) {
                    if let url = URL(string: "https://apps.apple.com/app/id6778506345") {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .background(Color.black.ignoresSafeArea()) // Ensure absolute background behind everything
    }
}

// MARK: - Custom Feature Illustrations
struct PromoFeatureIllustrationView: View {
    let title: String
    
    var body: some View {
        switch title {
        case "AI Nutrition Coach":
            PromoAINutritionCoachIllustration()
        case "Smart Food Vision":
            PromoSmartFoodVisionIllustration()
        case "AI Chef Studio":
            PromoAIChefStudioIllustration()
        case "Visual Progress":
            PromoVisualProgressIllustration()
        case "Intelligent Analytics":
            PromoIntelligentAnalyticsIllustration()
        default:
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.white)
        }
    }
}

struct PromoAINutritionCoachIllustration: View {
    @State private var rotateOrbit = 0.0
    @State private var pulseCircle = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.pink.opacity(0.15))
                .frame(width: 110, height: 110)
                .blur(radius: 12)
                
            Circle()
                .stroke(
                    LinearGradient(colors: [Color.pink.opacity(0.5), .clear, Color.pink.opacity(0.15)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 6])
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(rotateOrbit))
                
            Circle()
                .fill(Color.pink)
                .frame(width: 8, height: 8)
                .shadow(color: .pink, radius: 4)
                .offset(y: -65)
                .rotationEffect(.degrees(rotateOrbit))
                
            Circle()
                .stroke(Color.pink.opacity(0.3), lineWidth: 1.5)
                .frame(width: 80, height: 80)
                .scaleEffect(pulseCircle)
                .opacity(2.0 - pulseCircle)
                
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color.pink, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 66, height: 66)
                    .shadow(color: Color.pink.opacity(0.5), radius: 12)
                    
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .offset(x: 16, y: -16)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotateOrbit = 360
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseCircle = 1.3
            }
        }
    }
}

struct PromoViewfinderCorner: View {
    let rotation: Double
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 10))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 10, y: 0))
        }
        .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 10, height: 10)
        .rotationEffect(.degrees(rotation))
    }
}

struct PromoSmartFoodVisionIllustration: View {
    @State private var scanLineOffset: CGFloat = -40
    @State private var pulseTarget = 1.0
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    PromoViewfinderCorner(rotation: 0)
                    Spacer()
                    PromoViewfinderCorner(rotation: 90)
                }
                Spacer()
                HStack {
                    PromoViewfinderCorner(rotation: 270)
                    Spacer()
                    PromoViewfinderCorner(rotation: 180)
                }
            }
            .frame(width: 130, height: 110)
            .foregroundColor(Color.orange.opacity(0.8))
            
            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 100, height: 100)
                .blur(radius: 12)
            
            Circle()
                .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
                .frame(width: 75, height: 75)
                .scaleEffect(pulseTarget)
                .opacity(1.5 - pulseTarget)
            
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24))
                    .foregroundColor(Color.orange)
                    .shadow(color: Color.orange, radius: 5)
            }
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.orange, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120, height: 2)
                .shadow(color: Color.orange, radius: 4, y: 0)
                .offset(y: scanLineOffset)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scanLineOffset = 40
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseTarget = 1.2
            }
        }
    }
}

struct PromoAIChefStudioIllustration: View {
    @State private var steamOffset1: CGFloat = 0
    @State private var steamOffset2: CGFloat = 0
    @State private var steamOpacity1: Double = 0.8
    @State private var steamOpacity2: Double = 0.8
    @State private var panRotate = -4.0
    @State private var orbitRotate = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.12))
                .frame(width: 120, height: 120)
                .blur(radius: 12)
            
            ZStack {
                Image(systemName: "carrot.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .offset(x: -60, y: -18)
                
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                    .offset(x: 60, y: 12)
                
                Image(systemName: "cookbook.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .offset(x: 0, y: -60)
            }
            .rotationEffect(.degrees(orbitRotate))
            
            Group {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .blur(radius: 0.5)
                    .offset(x: -12, y: steamOffset1 - 20)
                    .opacity(steamOpacity1)
                
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 9, height: 9)
                    .blur(radius: 0.5)
                    .offset(x: 8, y: steamOffset2 - 20)
                    .opacity(steamOpacity2)
            }
            
            VStack {
                Spacer()
                Image(systemName: "frying.pan.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.yellow)
                    .shadow(color: Color.yellow.opacity(0.5), radius: 8)
                    .rotationEffect(.degrees(panRotate))
                    .padding(.bottom, 16)
            }
            .frame(height: 110)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                panRotate = 4.0
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                orbitRotate = 360
            }
            
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                steamOffset1 = -32
                steamOpacity1 = 0
            }
            withAnimation(.linear(duration: 2.1).repeatForever(autoreverses: false)) {
                steamOffset2 = -36
                steamOpacity2 = 0
            }
        }
    }
}

struct PromoVisualProgressIllustration: View {
    @State private var sliderOffset: CGFloat = -45
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 120, height: 120)
                .blur(radius: 12)
            
            ZStack {
                ZStack {
                    Color.black.opacity(0.4)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.2))
                    
                    VStack {
                        Spacer()
                        HStack {
                            Text("BEFORE")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(3)
                                .padding(8)
                            Spacer()
                        }
                    }
                }
                .frame(width: 130, height: 95)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                
                GeometryReader { geo in
                    let width = geo.size.width
                    let maskWidth = width/2 + sliderOffset
                    
                    ZStack {
                        Color.black.opacity(0.5)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.5), radius: 6)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("AFTER")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .cornerRadius(3)
                                    .padding(8)
                            }
                        }
                    }
                    .frame(width: width, height: geo.size.height)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                    .mask(
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(width: width - maskWidth)
                        }
                    )
                }
                .frame(width: 130, height: 95)
                
                ZStack {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 95)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .green.opacity(0.4), radius: 4)
                }
                .offset(x: sliderOffset)
            }
            .frame(width: 130, height: 95)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                sliderOffset = 45
            }
        }
    }
}

struct PromoIntelligentAnalyticsIllustration: View {
    @State private var ringTrim1: CGFloat = 0
    @State private var ringTrim2: CGFloat = 0
    @State private var dropletOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 120, height: 120)
                .blur(radius: 12)
            
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)
                .frame(width: 100, height: 100)
            
            Circle()
                .trim(from: 0, to: ringTrim1)
                .stroke(
                    LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
            
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)
                .frame(width: 82, height: 82)
            
            Circle()
                .trim(from: 0, to: ringTrim2)
                .stroke(
                    LinearGradient(colors: [Color.purple, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 82, height: 82)
                .rotationEffect(.degrees(-90))
            
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.cyan)
                    .shadow(color: Color.cyan, radius: 6)
                    .offset(y: dropletOffset)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) {
                ringTrim1 = 0.75
                ringTrim2 = 0.55
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                dropletOffset = -3
            }
        }
    }
}


// MARK: - Starfield Background
struct PromoCosmicStarfieldView: View {
    let themeColor: Color
    let motion: PromoMotionManager
    
    @State private var nebulaOffset1 = CGSize.zero
    @State private var nebulaOffset2 = CGSize.zero
    @State private var starSeed = Double.random(in: 0...100)
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.01, blue: 0.03),
                    Color(red: 0.03, green: 0.01, blue: 0.06),
                    Color(red: 0.01, green: 0.01, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geo in
                ZStack {
                
                Path { path in
                    let gridSpacing: CGFloat = 40
                    for x in stride(from: CGFloat(0), to: geo.size.width, by: gridSpacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: CGFloat(0), to: geo.size.height, by: gridSpacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.015), lineWidth: 1)
                
                Circle()
                    .fill(themeColor.opacity(0.18))
                    .frame(width: geo.size.width * 1.6, height: geo.size.width * 1.6)
                    .blur(radius: 120)
                    .offset(
                        x: -geo.size.width * 0.3 + nebulaOffset1.width + CGFloat(motion.roll * 40),
                        y: -geo.size.height * 0.2 + nebulaOffset1.height + CGFloat(motion.pitch * 40)
                    )
                
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                    .blur(radius: 100)
                    .offset(
                        x: geo.size.width * 0.4 + nebulaOffset2.width - CGFloat(motion.roll * 30),
                        y: geo.size.height * 0.5 + nebulaOffset2.height - CGFloat(motion.pitch * 30)
                    )
                
                PromoStarFieldPatternView(seed: starSeed)
            }
            .animation(.easeInOut(duration: 0.8), value: themeColor)
            .onAppear {
                withAnimation(.linear(duration: 25).repeatForever(autoreverses: true)) {
                    nebulaOffset1 = CGSize(width: 50, height: -30)
                }
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                    nebulaOffset2 = CGSize(width: -60, height: 45)
                }
            }
        }
        .ignoresSafeArea()
        }
    }
}

struct PromoStarFieldPatternView: View {
    let seed: Double
    @State private var twinkle = false
    
    private static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double, type: Int)] = {
        var temp: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double, type: Int)] = []
        for i in 0..<80 {
            let x = CGFloat((i * 17) % 100) / 100.0
            let y = CGFloat((i * 29) % 100) / 100.0
            let size = CGFloat(((i * 7) % 3) + 1)
            let opacity = Double(((i * 13) % 6) + 3) / 10.0
            let type = i % 4
            temp.append((x: x, y: y, size: size, opacity: opacity, type: type))
        }
        return temp
    }()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<Self.stars.count, id: \.self) { index in
                    let star = Self.stars[index]
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                        .opacity(star.opacity * (twinkle ? (star.type == 0 ? 0.3 : (star.type == 1 ? 1.4 : 1.0)) : 1.0))
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    twinkle = true
                }
            }
        }
    }
}

// MARK: - 3D Card
private struct PromoParallax3DCard: View {
    let item: PromoFeatureItem
    let activeIndex: Int
    let cardIndex: Int
    let totalCount: Int
    let motion: PromoMotionManager
    
    @State private var isVisible = false
    @State private var dragOffset: CGSize = .zero
    
    private var rollDegrees: Double {
        let baseRoll = max(-15, min(15, motion.roll * 180 / .pi))
        let dragRoll = Double(dragOffset.width) / 10.0
        return max(-20, min(20, baseRoll + dragRoll))
    }
    
    private var pitchDegrees: Double {
        let basePitch = max(-15, min(15, motion.pitch * 180 / .pi))
        let dragPitch = Double(dragOffset.height) / 10.0
        return max(-20, min(20, basePitch + dragPitch))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.black.opacity(0.45))
                .background(.ultraThinMaterial)
                .cornerRadius(32)
                .shadow(color: item.color.opacity(0.35), radius: 25, x: CGFloat(rollDegrees), y: CGFloat(pitchDegrees) + 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    item.color.opacity(0.6),
                                    .clear,
                                    item.color.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            
            VStack(spacing: 0) {
                // 1. Feature Illustration
                PromoFeatureIllustrationView(title: item.title)
                    .frame(height: 150)
                    .padding(.top, 24)
                    .offset(x: CGFloat(-rollDegrees * 2.0), y: CGFloat(-pitchDegrees * 2.0))
                
                // 2. Main Title
                Text(item.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .shadow(color: item.color.opacity(0.5), radius: 5)
                    .offset(x: CGFloat(-rollDegrees * 1.0), y: CGFloat(-pitchDegrees * 1.0))
                
                // 3. Description
                Text(item.description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .frame(height: 90, alignment: .top)
                    .offset(x: CGFloat(-rollDegrees * 0.5), y: CGFloat(-pitchDegrees * 0.5))
                
                // 4. Column Sub-features
                HStack(spacing: 16) {
                    PromoInfoColumn(icon: item.leftIcon, text: item.leftLabel, color: item.color)
                    PromoInfoColumn(icon: item.rightIcon, text: item.rightLabel, color: item.color)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .offset(x: CGFloat(-rollDegrees * 1.5), y: CGFloat(-pitchDegrees * 1.5))
                
                // 5. Card-embedded Progress Indicator
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        ForEach(0..<totalCount, id: \.self) { idx in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(idx == activeIndex ? item.color : Color.white.opacity(0.15))
                                .frame(width: idx == activeIndex ? 24 : 12, height: 4)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeIndex)
                    
                    Spacer()
                    
                    Text("\(activeIndex + 1) of \(totalCount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .rotation3DEffect(.degrees(pitchDegrees), axis: (x: -1.0, y: 0.0, z: 0.0), perspective: 0.4)
        .rotation3DEffect(.degrees(rollDegrees), axis: (x: 0.0, y: 1.0, z: 0.0), perspective: 0.4)
        .scaleEffect(isVisible ? 1 : 0.85)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragOffset = .zero
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

struct PromoInfoColumn: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.4), radius: 4)
            
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .tracking(0.5)
                .lineLimit(2)
                .frame(height: 24, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Button
struct PromoCosmicContinueButton: View {
    let title: String
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.7, blue: 1.0),
                                    Color(red: 0.6, green: 0.3, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color(red: 0.1, green: 0.7, blue: 1.0).opacity(0.4), radius: 15, x: 0, y: 8)
                .shadow(color: Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
