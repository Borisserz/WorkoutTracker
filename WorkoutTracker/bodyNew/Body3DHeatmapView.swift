//
//  Body3DHeatmapView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.03.26.
//
internal import SwiftUI
import SceneKit

/// SwiftUI обертка для 3D манекена на базе SceneKit
struct Body3DHeatmapView: UIViewRepresentable {
    
    var muscleIntensities: [String: Int]
    var isRecoveryMode: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false // Будем использовать свой красивый свет
        scnView.backgroundColor = .clear
        
        // 🎼 ОПТИМИЗАЦИЯ GPU: Отключаем непрерывный рендеринг и снижаем нагрузку
        scnView.antialiasingMode = .multisampling2X // 2X достаточно для Retina-экранов
        scnView.preferredFramesPerSecond = 30       // Экономим батарею
        scnView.rendersContinuously = false         // Рендер только при взаимодействии/анимации
        
        let scene = SCNScene()
        
        // 1. Собираем манекена
        let dummyNode = buildDummyNode()
        scene.rootNode.addChildNode(dummyNode)
        
        // 2. Настраиваем освещение
        setupLighting(in: scene)
        
        // 3. Настраиваем камеру
        setupCamera(in: scene)
        
        scnView.scene = scene
        
        // Первичная покраска
        applyColors(to: scene.rootNode)
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let scene = scnView.scene else { return }
        // Обновляем цвета при изменении данных
        applyColors(to: scene.rootNode)
    }
    
    // MARK: - 1. Построение 3D манекена (Сборка из примитивов)
    
    private func buildDummyNode() -> SCNNode {
        let dummyRoot = SCNNode()
        dummyRoot.name = "dummy_root"
        
        // --- Туловище (Torso) ---
        // Грудь (Front Upper)
        let chest = createPart(geo: SCNBox(width: 0.45, height: 0.3, length: 0.15, chamferRadius: 0.05), name: "chest", pos: SCNVector3(0, 1.45, 0.075))
        // Верх спины (Back Upper)
        let upperBack = createPart(geo: SCNBox(width: 0.45, height: 0.3, length: 0.15, chamferRadius: 0.05), name: "upper-back", pos: SCNVector3(0, 1.45, -0.075))
        // Пресс (Front Lower)
        let absNode = createPart(geo: SCNBox(width: 0.35, height: 0.3, length: 0.15, chamferRadius: 0.05), name: "abs", pos: SCNVector3(0, 1.15, 0.075))
        // Поясница (Back Lower)
        let lowerBack = createPart(geo: SCNBox(width: 0.35, height: 0.3, length: 0.15, chamferRadius: 0.05), name: "lower-back", pos: SCNVector3(0, 1.15, -0.075))
        
        // База (Таз) - декоративная
        let pelvis = createPart(geo: SCNBox(width: 0.4, height: 0.15, length: 0.25, chamferRadius: 0.05), name: "pelvis", pos: SCNVector3(0, 0.95, 0))
        
        // --- Голова и Шея (Декоративные) ---
        let head = createPart(geo: SCNSphere(radius: 0.12), name: "head", pos: SCNVector3(0, 1.8, 0))
        let neck = createPart(geo: SCNCylinder(radius: 0.05, height: 0.1), name: "neck", pos: SCNVector3(0, 1.65, 0))
        
        // --- Руки (Одинаковые имена для Левой и Правой) ---
        let shoulders = [
            createPart(geo: SCNSphere(radius: 0.11), name: "deltoids", pos: SCNVector3(0.28, 1.55, 0)),
            createPart(geo: SCNSphere(radius: 0.11), name: "deltoids", pos: SCNVector3(-0.28, 1.55, 0))
        ]
        
        let biceps = [
            createPart(geo: SCNCapsule(capRadius: 0.055, height: 0.3), name: "biceps", pos: SCNVector3(0.33, 1.3, 0.04)),
            createPart(geo: SCNCapsule(capRadius: 0.055, height: 0.3), name: "biceps", pos: SCNVector3(-0.33, 1.3, 0.04))
        ]
        
        let triceps = [
            createPart(geo: SCNCapsule(capRadius: 0.055, height: 0.3), name: "triceps", pos: SCNVector3(0.33, 1.3, -0.04)),
            createPart(geo: SCNCapsule(capRadius: 0.055, height: 0.3), name: "triceps", pos: SCNVector3(-0.33, 1.3, -0.04))
        ]
        
        let forearms = [
            createPart(geo: SCNCapsule(capRadius: 0.05, height: 0.3), name: "forearm", pos: SCNVector3(0.33, 0.95, 0)),
            createPart(geo: SCNCapsule(capRadius: 0.05, height: 0.3), name: "forearm", pos: SCNVector3(-0.33, 0.95, 0))
        ]
        
        // --- Ноги (Одинаковые имена для Левой и Правой) ---
        let glutes = [
            createPart(geo: SCNSphere(radius: 0.13), name: "gluteal", pos: SCNVector3(0.12, 0.95, -0.1)),
            createPart(geo: SCNSphere(radius: 0.13), name: "gluteal", pos: SCNVector3(-0.12, 0.95, -0.1))
        ]
        
        let quads = [
            createPart(geo: SCNCapsule(capRadius: 0.08, height: 0.45), name: "quadriceps", pos: SCNVector3(0.12, 0.65, 0.04)),
            createPart(geo: SCNCapsule(capRadius: 0.08, height: 0.45), name: "quadriceps", pos: SCNVector3(-0.12, 0.65, 0.04))
        ]
        
        let hamstrings = [
            createPart(geo: SCNCapsule(capRadius: 0.08, height: 0.45), name: "hamstring", pos: SCNVector3(0.12, 0.65, -0.04)),
            createPart(geo: SCNCapsule(capRadius: 0.08, height: 0.45), name: "hamstring", pos: SCNVector3(-0.12, 0.65, -0.04))
        ]
        
        let calves = [
            createPart(geo: SCNCapsule(capRadius: 0.06, height: 0.4), name: "calves", pos: SCNVector3(0.12, 0.2, -0.02)),
            createPart(geo: SCNCapsule(capRadius: 0.06, height: 0.4), name: "calves", pos: SCNVector3(-0.12, 0.2, -0.02))
        ]
        
        // Добавляем все в Root по частям, чтобы компилятор Swift не зависал
        var allNodes: [SCNNode] = [chest, upperBack, absNode, lowerBack, pelvis, head, neck]
        allNodes.append(contentsOf: shoulders)
        allNodes.append(contentsOf: biceps)
        allNodes.append(contentsOf: triceps)
        allNodes.append(contentsOf: forearms)
        allNodes.append(contentsOf: glutes)
        allNodes.append(contentsOf: quads)
        allNodes.append(contentsOf: hamstrings)
        allNodes.append(contentsOf: calves)

        for node in allNodes {
            dummyRoot.addChildNode(node)
        }
        
        // Опускаем манекена, чтобы центрировать по камере (камера смотрит в 0,0,0)
        dummyRoot.position = SCNVector3(0, -1.0, 0)
        
        return dummyRoot
    }
    
    // Вспомогательная функция для создания отдельной мышцы
    private func createPart(geo: SCNGeometry, name: String, pos: SCNVector3) -> SCNNode {
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        node.castsShadow = true
        
        // Настройка PBR материала для эффекта кибер-манекена
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.metalness.contents = 0.2
        material.roughness.contents = 0.5
        material.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.3)
        // Чтобы полупрозрачность работала корректно в 3D:
        material.transparencyMode = .dualLayer
        material.isDoubleSided = false
        
        node.geometry?.materials = [material]
        return node
    }
    
    // MARK: - 2. Логика Окрашивания
    
    private func applyColors(to rootNode: SCNNode) {
        // Рекурсивно обходим все ноды
        rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, let material = node.geometry?.firstMaterial else { return }
            
            // Если это декоративные части, оставляем базовый цвет
            if ["head", "neck", "pelvis", "dummy_root"].contains(name) {
                material.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.3)
                return
            }
            
            let color = calculateColor(for: name)
            
            // 🎼 Плавная анимация изменения цвета с пробуждением SceneKit
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            // Гарантируем, что рендерер обработает переход, а затем уснет
            SCNTransaction.completionBlock = {
                // SceneKit автоматически засыпает при rendersContinuously = false
            }
            material.diffuse.contents = color
            SCNTransaction.commit()
        }
    }
    
    private func calculateColor(for slug: String) -> UIColor {
        let baseColor = UIColor.systemGray.withAlphaComponent(0.3)
        let value = muscleIntensities[slug]
        
        if isRecoveryMode {
            // РЕЖИМ ВОССТАНОВЛЕНИЯ (100% - свежий (Серый), <50% - уставший (Красный))
            let recovery = value ?? 100
            
            if recovery >= 80 {
                return baseColor
            } else if recovery > 50 {
                return UIColor.systemOrange.withAlphaComponent(0.8)
            } else {
                return UIColor.systemRed.withAlphaComponent(0.9)
            }
            
        } else {
            // РЕЖИМ ЖИВОЙ АКТИВАЦИИ (0...100%)
            let tension = value ?? 0
            
            if tension == 0 {
                return baseColor
            } else {
                // Плавная смена прозрачности от 0.3 до 1.0 в зависимости от напряжения
                let opacity = 0.3 + (0.7 * (Double(tension) / 100.0))
                return UIColor.systemRed.withAlphaComponent(CGFloat(opacity))
            }
        }
    }
    
    // MARK: - 3. Камера и Освещение
    
    private func setupLighting(in scene: SCNScene) {
        // Окружающий свет (Ambient) - подсвечивает тени
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.intensity = 500 // Мягкий свет
        scene.rootNode.addChildNode(ambientLightNode)
        
        // Направленный свет (Directional) - создает блики и тени
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.intensity = 1500
        directionalLightNode.light?.castsShadow = true
        directionalLightNode.light?.shadowMode = .deferred
        directionalLightNode.light?.shadowSampleCount = 8
        
        // Устанавливаем свет спереди сверху
        directionalLightNode.position = SCNVector3(x: 2, y: 5, z: 5)
        directionalLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalLightNode)
        
        // Подсветка со спины (Rim light) для эффекта объема
        let rimLightNode = SCNNode()
        rimLightNode.light = SCNLight()
        rimLightNode.light?.type = .directional
        rimLightNode.light?.intensity = 800
        rimLightNode.position = SCNVector3(x: -2, y: 3, z: -5)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)
    }
    
    private func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Настраиваем поле зрения (FOV)
        cameraNode.camera?.fieldOfView = 45
        // Позиция камеры: чуть отдалена и поднята
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3.5)
        scene.rootNode.addChildNode(cameraNode)
    }
}
