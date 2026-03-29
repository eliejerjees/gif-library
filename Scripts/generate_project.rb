#!/usr/bin/env ruby

require "fileutils"

root = File.expand_path("..", __dir__)
vendor_gems = File.join(root, "vendor", "gems")
require "rubygems"
ENV["GEM_HOME"] = vendor_gems
ENV["GEM_PATH"] = vendor_gems
Gem.use_paths(vendor_gems, [vendor_gems])

require "xcodeproj"

PROJECT_NAME = "GifLibrary"
APP_TARGET_NAME = "GifLibrary"
EXTENSION_TARGET_NAME = "GifLibraryMessagesExtension"
IOS_DEPLOYMENT_TARGET = "17.0"

project_path = File.join(root, "#{PROJECT_NAME}.xcodeproj")
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes["LastSwiftUpdateCheck"] = "1600"
project.root_object.attributes["LastUpgradeCheck"] = "1600"

app_target = project.new_target(:application, APP_TARGET_NAME, :ios, IOS_DEPLOYMENT_TARGET)
extension_target = project.new_target(:messages_extension, EXTENSION_TARGET_NAME, :ios, IOS_DEPLOYMENT_TARGET)

project.root_object.attributes["TargetAttributes"] = {
  app_target.uuid => {},
  extension_target.uuid => {}
}

def set_common_build_settings(target, extension_safe:)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["SWIFT_VERSION"] = "5.9"
    settings["IPHONEOS_DEPLOYMENT_TARGET"] = IOS_DEPLOYMENT_TARGET
    settings["MARKETING_VERSION"] = "1.0"
    settings["CURRENT_PROJECT_VERSION"] = "1"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = ""
    settings["TARGETED_DEVICE_FAMILY"] = "1"
    settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
    settings["GENERATE_INFOPLIST_FILE"] = "NO"
    settings["CLANG_ENABLE_MODULES"] = "YES"
    settings["SWIFT_EMIT_LOC_STRINGS"] = "YES"
    settings["ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS"] = "NO"
    settings["APP_GROUP_IDENTIFIER"] = "group.com.example.GifLibrary.shared"
    settings["APPLICATION_EXTENSION_API_ONLY"] = extension_safe ? "YES" : "NO"
  end
end

set_common_build_settings(app_target, extension_safe: false)
set_common_build_settings(extension_target, extension_safe: true)

app_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.GifLibrary"
  config.build_settings["INFOPLIST_FILE"] = "App/HostApp/Info.plist"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "App/HostApp/GifLibrary.entitlements"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/Frameworks"
end

extension_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.GifLibrary.MessagesExtension"
  config.build_settings["INFOPLIST_FILE"] = "App/MessagesExtension/Info.plist"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "App/MessagesExtension/MessagesExtension.entitlements"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "iMessage App Icon"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"
  config.build_settings["SKIP_INSTALL"] = "YES"
end

def ensure_group(root_group, relative_directory)
  root_group.find_subpath(relative_directory, true)
end

def add_sources(project:, target:, files:)
  files.each do |relative_path|
    group_path = File.dirname(relative_path)
    group = ensure_group(project.main_group, group_path)
    file_ref = group.files.find { |file| file.path == File.basename(relative_path) } || group.new_file(relative_path)
    target.source_build_phase.add_file_reference(file_ref, true)
  end
end

def add_resources(project:, target:, files:)
  files.each do |relative_path|
    group_path = File.dirname(relative_path)
    group = ensure_group(project.main_group, group_path)
    file_ref = group.files.find { |file| file.path == File.basename(relative_path) } || group.new_file(relative_path)
    target.resources_build_phase.add_file_reference(file_ref, true)
  end
end

shared_sources = Dir.chdir(root) { Dir["Shared/**/*.swift"].sort }
app_sources = Dir.chdir(root) { Dir["App/HostApp/**/*.swift"].sort }
extension_sources = Dir.chdir(root) { Dir["App/MessagesExtension/**/*.swift"].sort }

add_sources(project: project, target: app_target, files: shared_sources + app_sources)
add_sources(project: project, target: extension_target, files: shared_sources + extension_sources)

add_resources(
  project: project,
  target: app_target,
  files: ["App/HostApp/Assets.xcassets"]
)

add_resources(
  project: project,
  target: extension_target,
  files: ["App/MessagesExtension/Assets.xcassets"]
)

app_target.add_dependency(extension_target)
embed_phase = app_target.new_copy_files_build_phase("Embed App Extensions")
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.add_file_reference(extension_target.product_reference, true)

project.save
puts "Generated #{project_path}"
