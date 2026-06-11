require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.any? { |t| t.name == 'WorkoutTrackerTests' }
  puts "Target WorkoutTrackerTests already exists."
  exit 0
end

app_target = project.targets.find { |t| t.name == 'WorkoutTracker' }

# Create test target
test_target = project.new_target(:unit_test_bundle, 'WorkoutTrackerTests', :ios, '17.0')

# Create group
tests_group = project.main_group.find_subpath('WorkoutTrackerTests', true)
tests_group.set_source_tree('<group>')
tests_group.set_path('WorkoutTrackerTests')

# Add files to group and target
file_ref = tests_group.new_reference('CNSCalculatorTests.swift')
test_target.add_file_references([file_ref])

# Add Target Dependency
test_target.add_dependency(app_target)

# Set up build settings
test_target.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/WorkoutTracker.app/WorkoutTracker'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.borisserzhanovich.WorkoutTrackerTests'
  config.build_settings['INFOPLIST_FILE'] = 'WorkoutTrackerTests/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

project.save
puts "Successfully added WorkoutTrackerTests target."
