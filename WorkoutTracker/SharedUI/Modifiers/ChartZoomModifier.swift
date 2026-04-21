

internal import SwiftUI
import Charts

struct ChartZoomState {
    var zoomScale: CGFloat = 1.0
    var panOffset: CGFloat = 0.0
    var lastZoomScale: CGFloat = 1.0
    var lastPanOffset: CGFloat = 0.0

    mutating func updateZoom(_ value: CGFloat, minZoom: CGFloat, maxZoom: CGFloat) {
        let newScale = lastZoomScale * value
        zoomScale = min(maxZoom, max(minZoom, newScale))
    }

    mutating func endZoom() {
        lastZoomScale = zoomScale
    }

    mutating func updatePan(_ translation: CGFloat) {
        panOffset = lastPanOffset + translation
    }

    mutating func endPan() {
        lastPanOffset = panOffset
    }

    mutating func reset() {
        zoomScale = 1.0
        panOffset = 0.0
        lastZoomScale = 1.0
        lastPanOffset = 0.0
    }
}

struct ChartZoomModifier: ViewModifier {
    let dateRange: ClosedRange<Date>
    @State private var zoomState = ChartZoomState()
    @Binding var currentZoomScale: CGFloat

    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 15.0

    init(dateRange: ClosedRange<Date>, currentZoomScale: Binding<CGFloat> = .constant(1.0)) {
        self.dateRange = dateRange
        self._currentZoomScale = currentZoomScale
    }

    func body(content: Content) -> some View {
        let totalRange = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let centerDate = dateRange.lowerBound.addingTimeInterval(totalRange / 2)

        let visibleRange = totalRange / Double(zoomState.zoomScale)

        let panSensitivity: Double
        let panTimeOffset: Double

        if zoomState.zoomScale > 1.0 {
            panSensitivity = max(50.0, 300.0 / Double(zoomState.zoomScale))
            panTimeOffset = Double(zoomState.panOffset) * totalRange / panSensitivity
        } else {
            panTimeOffset = 0.0
        }

        let startOffset = -visibleRange / 2 + panTimeOffset
        let endOffset = visibleRange / 2 + panTimeOffset

        let visibleStart = centerDate.addingTimeInterval(startOffset)
        let visibleEnd = centerDate.addingTimeInterval(endOffset)

        let clampedStart = max(dateRange.lowerBound, min(visibleStart, dateRange.upperBound - visibleRange))
        let clampedEnd = min(dateRange.upperBound, max(visibleEnd, dateRange.lowerBound + visibleRange))

        let finalRange = clampedStart...clampedEnd

        return content
            .chartXScale(domain: finalRange)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomState.updateZoom(value, minZoom: minZoom, maxZoom: maxZoom)
                            currentZoomScale = zoomState.zoomScale
                        }
                        .onEnded { _ in
                            zoomState.endZoom()
                            currentZoomScale = zoomState.zoomScale
                        },
                    DragGesture()
                        .onChanged { value in
                            if zoomState.zoomScale > 1.0 {
                                zoomState.updatePan(value.translation.width)
                            }
                        }
                        .onEnded { _ in
                            if zoomState.zoomScale > 1.0 {
                                zoomState.endPan()
                            } else {
                                zoomState.panOffset = 0.0
                                zoomState.lastPanOffset = 0.0
                            }
                        }
                )
            )
            .onTapGesture(count: 2) {

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    zoomState.reset()
                    currentZoomScale = 1.0
                }
            }
            .onAppear {
                currentZoomScale = zoomState.zoomScale
            }
    }
}

extension View {

    func chartZoomable(dateRange: ClosedRange<Date>, currentZoomScale: Binding<CGFloat> = .constant(1.0)) -> some View {
        modifier(ChartZoomModifier(dateRange: dateRange, currentZoomScale: currentZoomScale))
    }
}

