require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'WorkoutTracker' }
if target.nil?
  puts "Target WorkoutTracker not found."
  exit 1
end

# Find or create WorkoutTracker group
main_group = project.main_group.find_subpath('WorkoutTracker', true)
features_group = main_group.find_subpath('Features', true)
promo_group = features_group.find_subpath('Promo', true)

# The path to the file relative to the group's path
file_path = 'FoodTrackerPromoView.swift'

# Avoid adding duplicate references
existing_ref = promo_group.files.find { |f| f.path == file_path }
if existing_ref
  puts "File reference already exists."
else
  file_ref = promo_group.new_file(file_path)
  target.source_build_phase.add_file_reference(file_ref, true)
  project.save
  puts "Successfully added FoodTrackerPromoView.swift to Xcode project."
end
