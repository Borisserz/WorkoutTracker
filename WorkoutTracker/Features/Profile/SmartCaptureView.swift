

internal import SwiftUI

struct SmartCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SmartCaptureViewModel()

    let referenceImage: UIImage?
    let onCapture: (UIImage) -> Void

    @State private var overlayOpacity: Double = 0.4

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isAuthorized {
                cameraLayer
                overlayLayer
                hudLayer

                if viewModel.showFlash {
                    Color.white.ignoresSafeArea()
                        .transition(.opacity)
                }

                if let captured = viewModel.capturedImage {
                    previewLayer(captured)
                }

            } else {
                ProgressView().tint(.white)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var cameraLayer: some View {
        CameraPreview(session: viewModel.session)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var overlayLayer: some View {
        if let ref = referenceImage {
            Image(uiImage: ref)
                .resizable()
                .scaledToFill()
                .opacity(overlayOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                .overlay(
                    Rectangle()
                        .stroke(viewModel.isBodyAligned ? Color.green : Color.clear, lineWidth: viewModel.isBodyAligned ? 8 : 0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isBodyAligned)
                )
        } else {

            Image(systemName: "figure.stand")
                .resizable()
                .scaledToFit()
                .padding(40)
                .foregroundColor(viewModel.isBodyAligned ? .green : themeManager.current.background)
                .opacity(viewModel.isBodyAligned ? 0.6 : 0.3)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isBodyAligned)
        }
    }

    private var hudLayer: some View {
        VStack {

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white, Color.black.opacity(0.5))
                }
                Spacer()

                if referenceImage != nil {
                    Slider(value: $overlayOpacity, in: 0.1...0.8)
                        .tint(.cyan)
                        .frame(width: 150)
                }
            }
            .padding()

            Spacer()

            if let count = viewModel.countdown {
                Text("\(count)")
                    .font(.system(size: 150, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.current.background)
                    .shadow(color: .cyan, radius: 20, x: 0, y: 0)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            VStack(spacing: 16) {
                if viewModel.countdown == nil {

                    Text(viewModel.isBodyAligned ? "Perfect! Show ✌️ to capture." : "Align your body in the frame.")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.isBodyAligned ? .green : themeManager.current.background)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .animation(.easeInOut, value: viewModel.isBodyAligned)

                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.gestureController.gestureProgress))

                            .stroke(viewModel.isBodyAligned ? Color.green : Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: "hand.point.up.braille.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.gestureController.gestureProgress > 0 ? (viewModel.isBodyAligned ? .green : .cyan) : .white)
                    }
                    .padding(.bottom, 30)

                    .opacity(viewModel.isBodyAligned ? 1.0 : 0.5)
                    .animation(.easeInOut, value: viewModel.isBodyAligned)
                }
            }
        }
    }

    private func previewLayer(_ image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Button {
                        viewModel.retake()
                    } label: {
                        Text(LocalizedStringKey("Retake"))
                            .font(.headline)
                            .foregroundColor(themeManager.current.background)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                    }

                    Button {
                        onCapture(image)
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("Use Photo"))
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .safeAreaPadding(.bottom)
        }
        .transition(.opacity)
        .zIndex(10)
    }
}
