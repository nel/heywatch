=Hey!Watch - Video Encoding Web Service

Hey!Watch <http://heywatch.com> provides a simple and robust encoding plateform.
The service allows developers to access a fast, scalable and inexpensive web 
service to encode videos easier. The API can be easily integrated 
in any web or desktop applications.

The documentation of the API can be found at http://wiki.heywatch.com/API_Documentation


==Getting started

===Transfer a video, encode it in ipod format and download the encoded video

 require 'heywatch'
 include HeyWatch

 Base::establish_connection! :login => 'login', :password => 'password'

 raw_video = Discover.create(:url => 'http://youtube.com/watch?v=SXcpNZCyQJw', :download => true) do |percent, total_size, received|
   puts "#{percent}%"
 end
 
 ipod_format = Format.find_by_name('iPod 4:3')
 encoded_video = Job.create(:video_id => raw_video.id, :format_id => ipod_format.id) do |percent|
   puts "#{percent}%"
 end

 puts "downloading {encoded_video.title}"
 path = encoded_video.download
 puts "video saved in {path}"

 
===Upload a video from the disk, encode it with FTP auto transfer option

 raw_video = Video.create(:file => 'videos/myvideo.avi', :title => 'Funny video') do |percent, total_size, received|
   puts "#{percent}%"
 end

 Job.create :video_id => raw_video.id, :default_format => true, :ftp_directive => 'ftp://login:pass@host.com/heywatch_vids/'


===Generate a thumbnail

  v = EncodedVideo.find(5400)
  v.thumbnail :start => 15, :width => 640, :height => 480    


===Update your account

  account = Account.find
  account.update_attributes :ping_url_after_encode => 'http://yourhost.com/ping/encode'



==Integration in a rails application

This short HOWTO uses the ping options. So in your HeyWatch account, you must
configure all the ping URL (except transfer for this example).

Examples:

 ping_url_after_encode => http://myhost.com/ping/encode
 ping_url_if_error => http://myhost.com/ping/error


===Config

In your config/environment.rb:

  require 'heywatch'
  HeyWatch::Base::establish_connection! :login => 'login', :password => 'passwd'


===Item Model

 create_table "items", :force => true do |t|
   t.column "title",       :string,                          :null => false
   t.column "description", :text,                            :null => false
   t.column "created_at",  :datetime
   t.column "updated_at",  :datetime
   t.column "status",      :string,   :default => "working"
   t.column "url",         :string
   t.column "meta",        :text
   t.column "user_id",     :integer
 end

In app/models/item.rb:

 class Item < ActiveRecord::Base
   belongs_to :user
   serialize :meta
   after_create :convert

   # When HeyWatch send videos to your FTP,
   # they will be available to this HTTP url.
   def base_url
     "http://myhost.com/flv/#{self.id}/"
   end

   # Transfer the given URL and convert the video from 
   # this address in format 31 (flv format). When the encode
   # is done, the video will be sent to the specified FTP
   # with custom path.
   #
   # Note item_id which is a custom field.
   def convert        
     HeyWatch::Discover.create(
       :url              => self.url, 
       :download         => true, 
       :item_id          => self.id,
       :title            => self.title, 
       :automatic_encode => true,
       :format_id        => 31,
       :ftp_directive    => "ftp://login:passwd@myhost.com/flv/#{self.id}/"
     )
   end
 end


===Ping Controller

In app/controllers/ping_controller.rb:

 class PingController < ApplicationController
   before_filter :find_item

   def encode
     @encoded_video = HeyWatch::EncodedVideo.find(params[:encoded_video_id])
     @full_url = @item.base_url + @encoded_video.filename
     @item.status = 'finished'
     @item.meta = {
       :url       => @full_url,
       :thumb     => @full_url + ".jpg",
       :size      => @encoded_video.specs["size"],
       :mime_type => @encoded_video.specs["mime_type"],
       :length    => @encoded_video.specs.video["length"]
     }
     @item.save
     @encoded_video.job.video.destroy # delete the raw video
     @encoded_video.destroy # delete the encoded video
     render :nothing => true
   end

   def error
     if params[:discover_id]
       error_msg = "No video link found"
     else
       error_msg = HeyWatch::ErrorCode[params[:error_code].to_i]      
     end
     @item.update_attributes :status => 'error'
     ItemMailer.deliver_error(error_msg, @item.user)
     render :nothing => true
   end

   private

   # item_id is a custom_field sent in Item#convert.
   # Thanks to it, we can track the item.
   def find_item
     @item = Item.find params[:item_id]
   end
 end
