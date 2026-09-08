require 'xcodeproj'
require 'fileutils'
Dir.chdir(__dir__)
FileUtils.rm_rf('BlofyPlayer.xcodeproj')
project=Xcodeproj::Project.new('BlofyPlayer.xcodeproj')
target=project.new_target(:application,'BlofyPlayer',:ios,'16.0')

sources=project.main_group.new_group('Sources')
Dir.glob('BlofyPlayer/*.{swift,m,h}').sort.each do |p|
  r=sources.new_file(p)
  target.source_build_phase.add_file_reference(r) unless p.end_with?('.h')
end

resources=project.main_group.new_group('Resources')
Dir.glob('BlofyPlayer/Resources/**/*').select { |p| File.file?(p) }.sort.each do |p|
  r=resources.new_file(p)
  target.resources_build_phase.add_file_reference(r, true)
end

frameworks=project.main_group.new_group('Frameworks')
vlc_path='Vendor/VLCKit.xcframework'
raise 'Missing VLCKit.xcframework' unless File.directory?(vlc_path)
vlc_ref=frameworks.new_file(vlc_path)
target.frameworks_build_phase.add_file_reference(vlc_ref, true)
embed=target.new_copy_files_build_phase('Embed Frameworks')
embed.dst_subfolder_spec='10'
embed_file=embed.add_file_reference(vlc_ref, true)
embed_file.settings={'ATTRIBUTES'=>['CodeSignOnCopy','RemoveHeadersOnCopy']}

target.build_configurations.each do |c|
  c.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'=>'tv.blofy.player.ios',
    'PRODUCT_NAME'=>'BlofyPlayer',
    'SWIFT_VERSION'=>'5.0',
    'IPHONEOS_DEPLOYMENT_TARGET'=>'16.0',
    'TARGETED_DEVICE_FAMILY'=>'1,2',
    'INFOPLIST_FILE'=>'BlofyPlayer/Info.plist',
    'GENERATE_INFOPLIST_FILE'=>'NO',
    'CODE_SIGNING_ALLOWED'=>'NO',
    'CODE_SIGNING_REQUIRED'=>'NO',
    'CODE_SIGN_IDENTITY'=>'',
    'DEVELOPMENT_TEAM'=>'',
    'MARKETING_VERSION'=>'0.3.4',
    'CURRENT_PROJECT_VERSION'=>ENV.fetch('BLOFY_IOS_BUILD_NUMBER','1'),
    'FRAMEWORK_SEARCH_PATHS'=>['$(inherited)','$(PROJECT_DIR)/Vendor']
  })
end
project.save
scheme=Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(project.path,'BlofyPlayer',true)
puts 'Generated BlofyPlayer.xcodeproj with VLCKit and bundled resources'