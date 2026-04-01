//
//  MLWorkoutEngine.swift
//  WorkoutTracker
//

internal import SwiftUI
import Vision
import CoreML
import Combine
import AVFoundation
@MainActor
final class MLWorkoutEngine: ObservableObject {
    
    // MARK: - Published State (UI)
    @Published private(set) var currentAction: String = "Idle"
    @Published private(set) var confidence: Double = 0.0
    
    // MARK: - Configuration
    private let predictionWindowSize = 60
    private let stride = 5
    
    // MARK: - Internal State
    private var multiArraysWindow: [MLMultiArray] = []
    private var frameCounter = 0
    private var isPredicting = false
    
    private var lastConfidentPredictionTime: Date = .distantPast
    private let predictionCooldown: TimeInterval = 1.5
    
    // МОДИФИЦИРОВАНО: Опциональная модель
    private var actionClassifier: MLModel?
    
    private var predictionTask: Task<Void, Never>? = nil
    
    init() {
        loadModel()
    }
    
    deinit {
        predictionTask?.cancel()
        print("♻️ MLWorkoutEngine deallocated, prediction tasks cancelled")
    }
    
    private func loadModel() {
        Task.detached(priority: .userInitiated) {
            let config = MLModelConfiguration()
            if let model = try? WorkoutClassifier(configuration: config).model {
                await MainActor.run { [weak self] in
                    self?.actionClassifier = model
                }
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
    
    // MARK: - ML Prediction (Background)
    
    private func predictAction() {
        guard !isPredicting, let model = actionClassifier else { return }
        
        let windowToPredict = multiArraysWindow
        isPredicting = true
        
        predictionTask?.cancel()
        
        // 🚩 Используем [weak self] в Task.detached
        predictionTask = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    self?.isPredicting = false
                }
            }
            
            guard let self else { return }
            
            do {
                guard windowToPredict.count == self.predictionWindowSize else { return }
                
                let combinedArray = try MLMultiArray(
                    concatenating: windowToPredict,
                    axis: 0,
                    dataType: .float32
                )
                
                let input = try MLDictionaryFeatureProvider(dictionary: ["poses": combinedArray])
                let prediction = try await model.prediction(from: input)
                
                guard let labelFeature = prediction.featureValue(for: "label"),
                      let probabilitiesFeature = prediction.featureValue(for: "labelProbabilities") else {
                    return
                }
                
                let label = labelFeature.stringValue
                
                guard let probabilities = probabilitiesFeature.dictionaryValue as? [String: Double],
                      let conf = probabilities[label],
                      !Task.isCancelled else {
                    return
                }
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if conf > 0.45 {
                        self.currentAction = label
                        self.confidence = conf
                        self.lastConfidentPredictionTime = Date()
                    } else {
                        if Date().timeIntervalSince(self.lastConfidentPredictionTime) > self.predictionCooldown {
                            self.currentAction = "Idle"
                            self.confidence = 0.0
                        }
                    }
                }
                
            } catch {
                guard !Task.isCancelled else { return }
                print("⚠️ Action classification failed: \(error.localizedDescription)")
            }
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
