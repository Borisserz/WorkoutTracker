// ============================================================
// FILE: WorkoutTracker/MlVision/MLWorkoutEngine.swift
// ============================================================

internal import SwiftUI
import Vision
import CoreML
import Combine

@MainActor
final class MLWorkoutEngine: ObservableObject {
    
    // MARK: - Published State (UI & Gatekeeper)
    /// Флаг, указывающий, что пользователь выполняет циклическое действие, а не Restает.
    @Published private(set) var isUserActive: Bool = false
    @Published private(set) var confidence: Double = 0.0
    
    // MARK: - Configuration
    private let predictionWindowSize = 60
    private let stride = 5
    private let predictionCooldown: TimeInterval = 1.5
    
    // MARK: - Internal State
    private var multiArraysWindow: [MLMultiArray] = []
    private var frameCounter = 0
    private var isPredicting = false
    private var lastConfidentPredictionTime: Date = .distantPast
    
    private var actionClassifier: MLModel?
    private var predictionTask: Task<Void, Never>?
    
    init() {
        loadModel()
    }
    
    deinit {
        predictionTask?.cancel()
        print("♻️ MLWorkoutEngine deallocated, prediction tasks cancelled")
    }
    
    private func loadModel() {
        Task {
            let config = MLModelConfiguration()
            if let model = try? WorkoutClassifier(configuration: config).model {
                self.actionClassifier = model
            } else {
                print("❌ MLWorkoutEngine: Failed to load WorkoutClassifier")
            }
        }
    }
    
    // MARK: - Frame Processing
    
    func processFrame(observation: VNHumanBodyPoseObservation) {
        guard let multiArray = try? observation.keypointsMultiArray() else { return }
        
        multiArraysWindow.append(multiArray)
        if multiArraysWindow.count > predictionWindowSize {
            multiArraysWindow.removeFirst()
        }
        
        frameCounter += 1
        
        if multiArraysWindow.count == predictionWindowSize && (frameCounter % stride == 0) {
            predictAction()
        }
    }
    
    // MARK: - ML Prediction (Gatekeeper Logic)
    
    private func predictAction() {
        guard !isPredicting, let model = actionClassifier else { return }
        
        let windowToPredict = multiArraysWindow
        isPredicting = true
        predictionTask?.cancel()
        
        predictionTask = Task {
            let result = await performPrediction(on: windowToPredict, model: model)
            
            guard !Task.isCancelled else {
                self.isPredicting = false
                return
            }
            
            if let res = result {
                // Если модель уверена больше чем на 45% и это НЕ состояние Restа
                if res.confidence > 0.45 && res.label.lowercased() != "idle" {
                    self.isUserActive = true
                    self.confidence = res.confidence
                    self.lastConfidentPredictionTime = Date()
                } else {
                    // Даем небольшой кулдаун, чтобы не сбрасывать активность из-за одного неудачного кадра
                    if Date().timeIntervalSince(self.lastConfidentPredictionTime) > self.predictionCooldown {
                        self.isUserActive = false
                        self.confidence = 0.0
                    }
                }
            }
            self.isPredicting = false
        }
    }
    
    nonisolated private func performPrediction(on window: [MLMultiArray], model: MLModel) async -> (label: String, confidence: Double)? {
        do {
            let combinedArray = try MLMultiArray(concatenating: window, axis: 0, dataType: .float32)
            let input = try MLDictionaryFeatureProvider(dictionary: ["poses": combinedArray])
            let prediction = try await model.prediction(from: input)
            
            guard let labelFeature = prediction.featureValue(for: "label"),
                  let probabilitiesFeature = prediction.featureValue(for: "labelProbabilities"),
                  let probabilities = probabilitiesFeature.dictionaryValue as? [String: Double],
                  let conf = probabilities[labelFeature.stringValue] else {
                return nil
            }
            
            return (labelFeature.stringValue, conf)
        } catch {
            print("⚠️ Action classification failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func reset() {
        predictionTask?.cancel()
        isPredicting = false
        multiArraysWindow.removeAll()
        frameCounter = 0
        isUserActive = false
        confidence = 0.0
        lastConfidentPredictionTime = .distantPast
    }
}
