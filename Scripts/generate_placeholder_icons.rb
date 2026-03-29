#!/usr/bin/env ruby

require "fileutils"

root = File.expand_path("..", __dir__)

def write_gradient_ppm(path, width, height, start_rgb, end_rgb)
  File.open(path, "wb") do |file|
    file.write("P6\n#{width} #{height}\n255\n")

    height.times do |y|
      ratio = y.to_f / [height - 1, 1].max
      red = (start_rgb[0] + (end_rgb[0] - start_rgb[0]) * ratio).round
      green = (start_rgb[1] + (end_rgb[1] - start_rgb[1]) * ratio).round
      blue = (start_rgb[2] + (end_rgb[2] - start_rgb[2]) * ratio).round
      row = ([red, green, blue].pack("C*")) * width
      file.write(row)
    end
  end
end

def render_sizes(base_path, output_directory, mappings)
  mappings.each do |filename, dimensions|
    width, height = dimensions
    output_path = File.join(output_directory, filename)
    system("sips", "-s", "format", "png", "-z", height.to_s, width.to_s, base_path, "--out", output_path, out: File::NULL, err: File::NULL) or raise "Failed to render #{filename}"
  end
end

host_icon_dir = File.join(root, "App", "HostApp", "Assets.xcassets", "AppIcon.appiconset")
messages_icon_dir = File.join(root, "App", "MessagesExtension", "Assets.xcassets", "iMessage App Icon.stickersiconset")

host_base = File.join(root, "Scripts", "host-icon-base.ppm")
messages_base = File.join(root, "Scripts", "messages-icon-base.ppm")

write_gradient_ppm(host_base, 1024, 1024, [18, 23, 36], [43, 122, 242])
write_gradient_ppm(messages_base, 1024, 768, [17, 18, 27], [14, 95, 185])

render_sizes(host_base, host_icon_dir, {
  "AppIcon-20@2x.png" => [40, 40],
  "AppIcon-20@3x.png" => [60, 60],
  "AppIcon-29@2x.png" => [58, 58],
  "AppIcon-29@3x.png" => [87, 87],
  "AppIcon-40@2x.png" => [80, 80],
  "AppIcon-40@3x.png" => [120, 120],
  "AppIcon-60@2x.png" => [120, 120],
  "AppIcon-60@3x.png" => [180, 180],
  "AppIcon-20-ipad@1x.png" => [20, 20],
  "AppIcon-20-ipad@2x.png" => [40, 40],
  "AppIcon-29-ipad@1x.png" => [29, 29],
  "AppIcon-29-ipad@2x.png" => [58, 58],
  "AppIcon-40-ipad@1x.png" => [40, 40],
  "AppIcon-40-ipad@2x.png" => [80, 80],
  "AppIcon-76@1x.png" => [76, 76],
  "AppIcon-76@2x.png" => [152, 152],
  "AppIcon-83.5@2x.png" => [167, 167],
  "AppIcon-1024.png" => [1024, 1024]
})

render_sizes(messages_base, messages_icon_dir, {
  "MessagesIcon-60x45@2x.png" => [120, 90],
  "MessagesIcon-60x45@3x.png" => [180, 135],
  "MessagesIcon-67x50@2x.png" => [134, 100],
  "MessagesIcon-74x55@2x.png" => [148, 110],
  "MessagesIcon-27x20@2x.png" => [54, 40],
  "MessagesIcon-27x20@3x.png" => [81, 60],
  "MessagesIcon-32x24@3x.png" => [96, 72],
  "MessagesIcon-29x29@2x.png" => [58, 58],
  "MessagesIcon-29x29@3x.png" => [87, 87],
  "MessagesIcon-1024x768.png" => [1024, 768]
})

FileUtils.rm_f(host_base)
FileUtils.rm_f(messages_base)

puts "Placeholder icons rendered."
