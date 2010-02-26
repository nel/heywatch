require 'test/unit'
require File.dirname(__FILE__) + '/../lib/heywatch'

VIDEO_URL = 'http://www.youtube.com/watch?v=eBYLyt9Ptrs'

def discover_and_download_video(url)
  Discover.create(:url => url, :download => true, :automatic_encode => false) {|percent, total, received| puts "#{percent}%" }
end
