require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

test_target = project.targets.find { |t| t.name == 'WorkoutTrackerTests' }
tests_group = project.main_group.find_subpath('WorkoutTrackerTests', true)

new_files = [
  'PatternClassifierTests.swift',
  'AITrackerEngineTests.swift'
]

new_files.each do |file_name|
  # Add to group if not exists
  file_ref = tests_group.files.find { |f| f.path == file_name }
  unless file_ref
    file_ref = tests_group.new_reference(file_name)
  end
  
  # Add to target build phase if not exists
  unless test_target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
    test_target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{file_name} to test target"
  end
end

project.save
puts "Successfully added test files."
