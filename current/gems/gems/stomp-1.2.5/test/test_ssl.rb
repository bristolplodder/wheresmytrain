# -*- encoding: utf-8 -*-

$:.unshift(File.dirname(__FILE__))

require 'test_helper'

=begin

  Main class for testing Stomp::SSLParams.

=end
class TestSSL < Test::Unit::TestCase
  include TestBase
  
  def setup
    @conn = get_ssl_connection()
  end

  def teardown
    @conn.disconnect if @conn && @conn.open? # allow tests to disconnect
  end
  #
  def test_ssl_0000
    assert @conn.open?
  end

  # Test SSLParams basic.
  def test_ssl_0010_parms
    ssl_params = Stomp::SSLParams.new
    assert ssl_params.ts_files.nil?
    assert ssl_params.cert_file.nil?
    assert ssl_params.key_file.nil?
    assert ssl_params.fsck.nil?
  end

  # Test using correct parameters.
  def test_ssl_0020_noraise
    assert_nothing_raised {
      ssl_parms = Stomp::SSLParams.new(:cert_file => "dummy1", :key_file => "dummy2")
    }
    assert_nothing_raised {
      ssl_parms = Stomp::SSLParams.new(:ts_files => "dummyts1")
    }
    assert_nothing_raised {
      ssl_parms = Stomp::SSLParams.new(:ts_files => "dummyts1", 
        :cert_file => "dummy1", :key_file => "dummy2")
    }
  end

  # Test using incorrect / incomplete parameters.
  def test_ssl_0030_raise
    assert_raise(Stomp::Error::SSLClientParamsError) {
      ssl_parms = Stomp::SSLParams.new(:cert_file => "dummy1")
    }
    assert_raise(Stomp::Error::SSLClientParamsError) {
      ssl_parms = Stomp::SSLParams.new(:key_file => "dummy2")
    }
  end

  # Test that :fsck works.
  def test_ssl_0040_fsck
    assert_raise(Stomp::Error::SSLNoCertFileError) {
      ssl_parms = Stomp::SSLParams.new(:cert_file => "dummy1", 
        :key_file => "dummy2", :fsck => true)
    }
    assert_raise(Stomp::Error::SSLNoKeyFileError) {
      ssl_parms = Stomp::SSLParams.new(:cert_file => __FILE__,
        :key_file => "dummy2", :fsck => true)
    }
    assert_raise(Stomp::Error::SSLNoTruststoreFileError) {
      ssl_parms = Stomp::SSLParams.new(:ts_files => "/tmp/not-likely-here.txt", 
        :fsck => true)
    }
  end

  #
end if ENV['STOMP_TESTSSL']

