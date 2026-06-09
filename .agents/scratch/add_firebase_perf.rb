require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'WorkoutTracker' }
if target
  puts "Found target: #{target.name}"
  
  has_perf = target.frameworks_build_phase.files.any? { |f| f.display_name == 'FirebasePerformance' }
  
  if has_perf
    puts "FirebasePerformance is already linked."
  else
    puts "Adding FirebasePerformance..."
    pkg_ref = project.root_object.package_references.find { |pr| pr.repositoryURL.include?('firebase-ios-sdk') }
    if pkg_ref
      product_ref = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
      product_ref.product_name = 'FirebasePerformance'
      product_ref.package = pkg_ref
      
      target.package_product_dependencies << product_ref
      
      build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
      build_file.product_ref = product_ref
      target.frameworks_build_phase.files << build_file
      
      project.save
      puts "Successfully added FirebasePerformance"
    else
      puts "Could not find firebase-ios-sdk package"
    end
  end
end
