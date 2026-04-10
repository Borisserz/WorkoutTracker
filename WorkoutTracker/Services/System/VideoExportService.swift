//
//  VideoExportService.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 4.04.26.
//

// ============================================================
// FILE: WorkoutTracker/Services/System/VideoExportService.swift
// ============================================================

import Foundation
import AVFoundation
import CoreGraphics
import UIKit

enum VideoExportError: LocalizedError {
    case writerInitializationFailed
    case pixelBufferFailed
    case assetExportFailed
    
    var errorDescription: String? {
        switch self {
        case .writerInitializationFailed: return String(localized: "Failed to initialize video writer.")
        case .pixelBufferFailed: return String(localized: "Failed to allocate pixel buffer.")
        case .assetExportFailed: return String(localized: "Failed to export final video.")
        }
    }
}

/// Изолированный актор для тяжелой работы с видео
actor VideoExportService {
    
    func createVideo(from frames: [CGImage], fps: Int32 = 30, audioName: String? = nil) async throws -> URL {
        guard let firstFrame = frames.first else { throw VideoExportError.writerInitializationFailed }
        
        let width = firstFrame.width
        let height = firstFrame.height
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("HeatmapExport_\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        guard assetWriter.canAdd(writerInput) else { throw VideoExportError.writerInitializationFailed }
        assetWriter.add(writerInput)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        let frameDuration = CMTimeMake(value: 1, timescale: fps)
        var frameCount: Int64 = 0
        
        for cgImage in frames {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms yield
            }
            
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
            guard let pixelBuffer = pixelBuffer(from: cgImage, width: width, height: height) else {
                throw VideoExportError.pixelBufferFailed
            }
            
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            frameCount += 1
        }
        
        writerInput.markAsFinished()
        await assetWriter.finishWriting()
        
        // Опциональное добавление тяжелого бита (Аудио)
        if let audioName = audioName, let audioURL = Bundle.main.url(forResource: audioName, withExtension: "mp3") {
            return try await mixAudio(videoURL: outputURL, audioURL: audioURL)
        }
        
        return outputURL
    }
    
    private func pixelBuffer(from cgImage: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
    
    private func mixAudio(videoURL: URL, audioURL: URL) async throws -> URL {
        let composition = AVMutableComposition()
        let videoAsset = AVAsset(url: videoURL)
        let audioAsset = AVAsset(url: audioURL)
        
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            return videoURL
        }
        
        let videoDuration = try await videoAsset.load(.duration)
        
        let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        try compVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
        try compAudioTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: videoDuration), of: audioTrack, at: .zero)
        
        let finalURL = FileManager.default.temporaryDirectory.appendingPathComponent("FinalHeatmap_\(UUID().uuidString).mp4")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExportError.assetExportFailed
        }
        
        exportSession.outputURL = finalURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        return finalURL
    }
}
