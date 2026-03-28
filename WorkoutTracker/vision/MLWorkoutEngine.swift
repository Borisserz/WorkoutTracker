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
    private var observations: [VNHumanBodyPoseObservation] = []
    private var frameCounter = 0
    
    /// Флаг для защиты от наслоения предикшенов (backpressure)
    private var isPredicting = false
    
    /// Гистерезис (сглаживание) для удержания распознанного экшена
    private var lastConfidentPredictionTime: Date = .distantPast
    private let predictionCooldown: TimeInterval = 1.5 // 1.5 секунды
    
    // Модель Action Classifier
    private var actionClassifier: MLModel?
    
    // MARK: - Init
    init() {
        loadModel()
    }
    
    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            // В реальном проекте: try WorkoutClassifier(configuration: config).model
            self.actionClassifier = try WorkoutClassifier(configuration: config).model
        } catch {
            print("❌ MLWorkoutEngine: Failed to load WorkoutClassifier: \(error)")
        }
    }
    
    // MARK: - Frame Processing
    
    /// Принимает новый кадр от CameraDelegate
    func processFrame(observation: VNHumanBodyPoseObservation) {
        // 1. Добавляем кадр в конец окна
        observations.append(observation)
        
        // 2. Поддерживаем строгое скользящее окно (FIFO)
        if observations.count > predictionWindowSize {
            observations.removeFirst()
        }
        
        frameCounter += 1
        
        // 3. Запускаем классификацию с учетом Stride (каждые 5 кадров)
        if observations.count == predictionWindowSize && (frameCounter % stride == 0) {
            predictAction()
        }
    }
    
    // MARK: - ML Prediction (Background)
    
    private func predictAction() {
        // Защита: не запускаем новый запрос, если старый еще считается
        guard !isPredicting, let model = actionClassifier else { return }
        
        // Делаем копию массива для безопасной передачи в фоновый поток
        let windowToPredict = observations
        isPredicting = true
        
        Task.detached(priority: .userInitiated) {
            defer {
                // Гарантированно освобождаем блокировку после завершения
                Task { @MainActor in self.isPredicting = false }
            }
            
            do {
                // 1. Извлекаем MLMultiArray из каждого кадра
                let multiArrays = try windowToPredict.compactMap { try $0.keypointsMultiArray() }
                
                // Убеждаемся, что никто не потерялся
                guard multiArrays.count == self.predictionWindowSize else { return }
                
                // 2. Склеиваем массив в единый таймлайн (Shape: 60 x 3 x 18)
                let combinedArray = try MLMultiArray(
                    concatenating: multiArrays,
                    axis: 0,
                    dataType: .float32
                )
                
                // 3. Формируем входные данные
                let input = try MLDictionaryFeatureProvider(dictionary: ["poses": combinedArray])
                
                // 4. Выполняем предикшен
                let prediction = try await model.prediction(from: input)
                
                // 5. Парсим результаты
                guard let labelFeature = prediction.featureValue(for: "label"),
                      let probabilitiesFeature = prediction.featureValue(for: "labelProbabilities") else {
                    return
                }
                
                let label = labelFeature.stringValue // Это точно строка, nil быть не может
                
                guard let probabilities = probabilitiesFeature.dictionaryValue as? [String: Double],
                      let conf = probabilities[label] else {
                    return
                }
                
                // 6. Отдаем результат в UI на MainActor с поддержкой гистерезиса
                await MainActor.run {
                    // Чуть снижаем порог для большего доверия сырой модели
                    if conf > 0.45 {
                        self.currentAction = label
                        self.confidence = conf
                        self.lastConfidentPredictionTime = Date() // Запоминаем момент успешного распознавания
                    } else {
                        // Сбрасываем только если прошло достаточно времени с последнего успешного распознавания
                        if Date().timeIntervalSince(self.lastConfidentPredictionTime) > self.predictionCooldown {
                            self.currentAction = "Idle"
                            self.confidence = 0.0
                        }
                    }
                }
                
            } catch {
                print("⚠️ Action classification failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Сброс состояния (например, при смене упражнения или остановке тренировки)
    func reset() {
        observations.removeAll()
        frameCounter = 0
        currentAction = "Idle"
        confidence = 0.0
        lastConfidentPredictionTime = .distantPast
    }
}
