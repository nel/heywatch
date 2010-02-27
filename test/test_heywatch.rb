require File.dirname(__FILE__) + '/test_helper.rb'
include HeyWatch


class TestHeywatch < Test::Unit::TestCase
  def setup
    Base::establish_connection! :login => get_credentials(:login), :password => get_credentials(:password)
  end
  
  # Authentification
  
  def test_should_be_authorized
    assert_kind_of Account, Account.find
  end
  
  def test_should_raise_if_not_authorized
    assert_raise(NotAuthorized) { Auth::create 'fakelogin', 'fakepasswd' }
  end
  
  def test_should_raise_if_not_logged_in
    Base::disconnect!
    assert_raise(NotAuthorized) { Format.find(:first) }
  end
  
  # Finding
  
  def test_should_return_the_first_format
    assert_kind_of Format, Format.find(:first)
  end
  
  def test_should_return_format_with_id
    id = Format.find(:first).id
    assert_kind_of Format, Format.find(id)
  end
  
  def test_should_return_all_formats
    formats = Format.find(:all)
    assert_kind_of Array, formats
    assert formats.size > 0
  end
  
  def test_should_return_just_three_formats
    formats = Format.find(:all, :limit => 3)
    assert formats.size == 3
  end
  
  def test_should_return_all_ipod_formats
    formats = Format.find(:all, :conditions => {:name => /ipod/i})
    formats.each do |f|
      assert f.name =~ /ipod/i
    end
  end
  
  def test_should_return_all_formats_using_xvid_codec
    formats = Format.find(:all, :conditions => {:video_codec => 'xvid'})
    formats.each do |f|
      assert f.video_codec == 'xvid'
    end
  end
  
  def test_should_return_all_formats_having_width_less_than_176
    formats = Format.find(:all, :conditions => {:width => '< 176'})
    formats.each do |f|
      assert f.width < 176
    end
  end
  
  def test_should_find_by_name
    assert_equal 'Mobile 3GP', Format.find_by_name('Mobile 3GP').name
  end
  
  def test_should_find_all_by_video_codec
    formats = Format.find_all_by_video_codec('xvid')
    assert_kind_of Array, formats
    formats.each do |f|
      assert f.video_codec =='xvid'
    end
  end
  
  def test_should_raise_if_not_found
    assert_raise(ResourceNotFound) { Format.find(99999999) }
  end
  
  # Discover
  
  def test_should_create_discover
    discover = Discover.create :url => VIDEO_URL
    assert_kind_of Discover, discover
  end
  
  def test_should_create_discover_and_go_until_raw_video
    raw_video = discover_and_download_video VIDEO_URL
    assert_kind_of Video, raw_video
  end
  
  def test_should_raise_because_invalid_url
    assert_raise(RequestError) { Discover.create :url => 'invalid_url' }
  end
  
  def test_should_raise_because_no_video_found
    assert_raise(VideoNotFound) { discover_and_download_video 'http://google.com' }
  end
  
  # Job
  
  # Each of these tests consume 1 credit.
  
  #def test_should_create_job
  #  raw_video = discover_and_download_video VIDEO_URL
  #  job = Job.create :video_id => raw_video.id, :format_id => Format.find_by_name('Mobile 3GP').id
  #  assert_kind_of Job, job
  #end
  
  #def test_should_create_job_and_go_until_encoded_video
  #  raw_video = discover_and_download_video VIDEO_URL
  #  encoded_video = Job.create(:video_id => raw_video.id, :format_id => Format.find_by_name('Mobile 3GP').id) do |percent|
  #    puts "#{percent}%"
  #  end
  #  assert_kind_of EncodedVideo, encoded_video
  #end
  
  def test_should_raise_if_format_doesnt_exist
    raw_video = discover_and_download_video VIDEO_URL
    assert_raise(RequestError) { Job.create :video_id => raw_video.id, :format_id => 80000 }
  end
  
  def test_should_raise_if_video_doesnt_exist
    assert_raise(RequestError) { Job.create :video_id => 150, :format_id => 2 }
  end
  
  # Update and Delete
  
  def test_should_update_the_title
    raw_video = discover_and_download_video VIDEO_URL
    raw_video.update_attributes :title => 'mytitle'
    assert_equal 'mytitle', Video.find(raw_video.id).title
  end
  
  def test_should_delete_the_video
    raw_video = discover_and_download_video VIDEO_URL
    assert raw_video.destroy
  end
  
  def test_should_raise_if_video_doesnt_exist
    assert_raise(ResourceNotFound) { Video.destroy(99999999999) }
    assert_raise(ResourceNotFound) { Video.update(99999999999, :title => 'mytitle') }
  end
  
  # Browser
  
  def test_should_retry_connection_attempt_on_network_errors
    [Errno::EPIPE, Timeout::Error, Errno::EPIPE, Errno::EINVAL, EOFError].each do |network_exception|
      retrial = 0
      assert_raise(network_exception) {
        Browser.with_http {|http| retrial += 1; raise network_exception}
      }
      assert_equal 3, retrial
    end
  end
end
