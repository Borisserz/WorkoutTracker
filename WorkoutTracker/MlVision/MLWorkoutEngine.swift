//
//  MLWorkoutEngine.swift
//  WorkoutTracker
//

internal import SwiftUI
import Vision
import CoreML
import Combine

@MainActor
final class MLWorkoutEngine: ObservableObject {
    
    // MARK: - Published State (UI)
    @Published private(set) var currentAction: String = "Idle"
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
    
    // MARK: - ML Prediction (Structured Concurrency)
    
    private func predictAction() {
        guard !isPredicting, let model = actionClassifier else { return }
        
        let windowToPredict = multiArraysWindow
        isPredicting = true
        predictionTask?.cancel()
        
        // Обычный Task наследует контекст, но мы вызываем nonisolated метод для снятия нагрузки с MainActor
        predictionTask = Task {
            let result = await performPrediction(on: windowToPredict, model: model)
            
            // Защита от отмены задачи
            guard !Task.isCancelled else {
                self.isPredicting = false
                return
            }
            
            // Обновляем состояние безопасно на MainActor
            if let res = result {
                if res.confidence > 0.45 {
                    self.currentAction = res.label
                    self.confidence = res.confidence
                    self.lastConfidentPredictionTime = Date()
                } else {
                    if Date().timeIntervalSince(self.lastConfidentPredictionTime) > self.predictionCooldown {
                        self.currentAction = "Idle"
                        self.confidence = 0.0
                    }
                }
            }
            self.isPredicting = false
        }
    }
    
    // Тяжелая математика вынесена из MainActor. Передаем только Sendable или изолированные параметры.
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
        currentAction = "Idle"
        confidence = 0.0
        lastConfidentPredictionTime = .distantPast
    }
}
