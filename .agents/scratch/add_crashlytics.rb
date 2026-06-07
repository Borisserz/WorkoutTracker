require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'WorkoutTracker' }
if target
  puts "Found target: #{target.name}"
  
  # Check if we already have it
  has_crashlytics = target.frameworks_build_phase.files.any? { |f| f.display_name == 'FirebaseCrashlytics' }
  
  if has_crashlytics
    puts "Crashlytics is already linked."
  else
    puts "Adding Crashlytics..."
    # Firebase is already added as a package. We need to find the package reference.
    pkg_ref = project.root_object.package_references.find { |pr| pr.repositoryURL.include?('firebase-ios-sdk') }
    if pkg_ref
      puts "Found firebase-ios-sdk package reference"
      
      # Create a new XCRemoteSwiftPackageReference if it doesn't exist? No, the package reference exists.
      # We just need to add the product reference to the target's dependencies.
      product_ref = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
      product_ref.product_name = 'FirebaseCrashlytics'
      product_ref.package = pkg_ref
      
      target.package_product_dependencies << product_ref
      
      # And add to frameworks build phase
      build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
      build_file.product_ref = product_ref
      target.frameworks_build_phase.files << build_file
      
      project.save
      puts "Successfully added FirebaseCrashlytics"
    else
      puts "Could not find firebase-ios-sdk package"
    end
  end
end
