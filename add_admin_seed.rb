require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'WorkoutTracker' }
app_group = project.main_group.find_subpath('WorkoutTracker/AppCore', true)

file_name = 'AdminSeedService.swift'
file_path = 'WorkoutTracker/AppCore/AdminSeedService.swift'

file_ref = app_group.files.find { |f| f.path == file_name }
unless file_ref
  file_ref = app_group.new_file(file_name)
end

unless app_target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
  app_target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{file_name} to app target"
end

project.save
puts "Successfully added #{file_name}."
