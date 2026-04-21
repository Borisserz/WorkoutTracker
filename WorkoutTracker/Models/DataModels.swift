import Foundation

struct MuscleGroup: Identifiable {
    let id = UUID()
    let slug: String
    let name: String
    let paths: [String] 

    init(slug: String, name: String, paths: [String]) {
        self.slug = slug
        self.name = name
        self.paths = paths
    }
}
