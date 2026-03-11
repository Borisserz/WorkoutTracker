import Foundation
import SwiftData

@Model
class MuscleColorPreference {
    @Attribute(.unique) var muscleName: String
    var hexColor: String
    
    init(muscleName: String, hexColor: String) {
        self.muscleName = muscleName
        self.hexColor = hexColor
    }
}
