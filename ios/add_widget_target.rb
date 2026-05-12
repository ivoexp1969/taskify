require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

# Check if widget target already exists
if project.targets.any? { |t| t.name == 'TaskifyWidget' }
  puts "Widget target already exists"
  exit 0
end

# Create widget extension target
widget_target = project.new_target(:app_extension, 'TaskifyWidget', :ios, '14.0')

# Add Swift source file
widget_group = project.main_group.new_group('TaskifyWidget', 'TaskifyWidget')
swift_file = widget_group.new_file('TaskifyWidget/TaskifyWidget.swift')
info_plist = widget_group.new_file('TaskifyWidget/Info.plist')
entitlements_file = widget_group.new_file('TaskifyWidget/TaskifyWidget.entitlements')

widget_target.source_build_phase.add_file_reference(swift_file)

# Build settings
widget_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['INFOPLIST_FILE'] = 'TaskifyWidget/Info.plist'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ivoexp.taskify.widget'
  config.build_settings['DEVELOPMENT_TEAM'] = 'YP2QH7PM93'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'TaskifyWidget/TaskifyWidget.entitlements'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# Add WidgetKit framework
widget_target.frameworks_build_phase.add_file_reference(
  project.frameworks_group.new_file('System/Library/Frameworks/WidgetKit.framework')
)
widget_target.frameworks_build_phase.add_file_reference(
  project.frameworks_group.new_file('System/Library/Frameworks/SwiftUI.framework')
)

# Embed widget in main Runner target
runner_target = project.targets.find { |t| t.name == 'Runner' }
embed_phase = runner_target.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13' # PlugIns
ref = embed_phase.add_file_reference(widget_target.product_reference)
ref.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "Widget target added successfully"
