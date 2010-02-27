require 'test/unit'
require File.dirname(__FILE__) + '/../lib/heywatch' unless defined?(HeyWatch)

VIDEO_URL = 'http://www.youtube.com/watch?v=eBYLyt9Ptrs'

def discover_and_download_video(url)
  Discover.create(:url => url, :download => true, :automatic_encode => false) {|percent, total, received| puts "#{percent}%" }
end

def get_credentials(type)
  filename = "#{ENV['HOME']}/.heywatch-#{type}"
  return File.read(filename).chomp if File.exists?(filename)
  nil
end