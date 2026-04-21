

import Foundation
import UIKit

enum ImageStoreError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return String(localized: "Could not compress image data.")
        }
    }
}

actor LocalImageStore {
    static let shared = LocalImageStore()

    private let fileManager = FileManager.default
    private var documentDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() {}

    func saveImage(_ image: UIImage, compressionQuality: CGFloat = 0.6) throws -> String {

        let resizedImage = resizeImage(image, targetSize: CGSize(width: 1080, height: 1080))

        guard let data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw ImageStoreError.compressionFailed
        }

        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documentDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)
        return fileName
    }

    func loadImage(named fileName: String) -> UIImage? {
        let fileURL = documentDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    func deleteImage(named fileName: String) {
        let fileURL = documentDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    func saveImages(_ images: [UIImage]) async throws -> [String] {
        return try await withThrowingTaskGroup(of: String.self) { group in
            for image in images {
                group.addTask {
                    try await self.saveImage(image)
                }
            }
            var fileNames: [String] = []
            for try await fileName in group {
                fileNames.append(fileName)
            }
            return fileNames
        }
    }

    func deleteImages(named fileNames: [String]) {
        for fileName in fileNames {
            let fileURL = documentDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let figure = min(widthRatio, heightRatio)

        if figure >= 1.0 { return image } 

        let newSize = CGSize(width: size.width * figure, height: size.height * figure)
        let rect = CGRect(origin: .zero, size: newSize)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? image
    }
}
