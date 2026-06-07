require 'xcodeproj'

project_path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'WorkoutTracker' }

phase_name = 'Firebase Crashlytics'
phase = target.shell_script_build_phases.find { |p| p.name == phase_name }
if phase
  puts "Phase already exists"
else
  phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  phase.name = phase_name
  phase.shell_script = '"${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"'
  target.build_phases << phase
  project.save
  puts "Added Crashlytics build phase"
end
