require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'WorkoutTracker' }

# Find the Firebase package
firebase_package = project.root_object.package_references.find do |pkg|
  pkg.repositoryURL.include?('firebase-ios-sdk')
end

if firebase_package
  puts "Found Firebase package!"
  
  # Check if it already exists
  existing = target.frameworks_build_phase.files.find do |f|
    f.product_ref && f.product_ref.product_name == 'FirebaseAnalytics'
  end
  
  if existing
    puts "FirebaseAnalytics is already linked."
  else
    puts "Adding FirebaseAnalytics to target..."
    product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    product.product_name = 'FirebaseAnalytics'
    product.package = firebase_package
    
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = product
    
    target.frameworks_build_phase.files << build_file
    
    project.save
    puts "Successfully added and saved project!"
  end
else
  puts "Could not find firebase-ios-sdk package in project."
end
