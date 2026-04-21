

import Foundation
import UIKit

class ProfileImageManager {
    static let shared = ProfileImageManager()

    private let fileName = "profile_avatar.jpg"

    private init() {}

    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    func saveImage(_ image: UIImage) {
        guard let url = fileURL,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url)
    }

    func loadImage() -> UIImage? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
