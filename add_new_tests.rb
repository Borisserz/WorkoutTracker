require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

test_target = project.targets.find { |t| t.name == 'WorkoutTrackerTests' }
tests_group = project.main_group.find_subpath('WorkoutTrackerTests', true)

files_to_add = [
  'OneRepMaxCalculatorTests.swift',
  'CalorieCalculatorTests.swift',
  'UnitsManagerTests.swift',
  'RestTimerManagerTests.swift'
]

files_to_add.each do |file|
  unless tests_group.files.any? { |f| f.path == file }
    file_ref = tests_group.new_reference(file)
    test_target.add_file_references([file_ref])
    puts "Added #{file} to target"
  end
end

project.save
puts "Project saved"
