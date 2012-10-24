# -*- encoding: utf-8 -*-

$:.unshift(File.dirname(__FILE__))

require 'test_helper'

=begin

  Main class for testing Stomp::HeadreCodec methods.

=end
class TestCodec < Test::Unit::TestCase
  include TestBase
  
  def setup
    @conn = get_connection()
    # Data for multi_thread tests
    @max_threads = 20
    @max_msgs = 100
  end

  def teardown
    @conn.disconnect if @conn.open? # allow tests to disconnect
  end

  # Test that the codec does nothing to strings that do not need encoding.
  def test_1000_check_notneeded
    test_data = [
      "a",
      "abcdefghijklmnopqrstuvwxyz",
      "ªºÀÁ",
      "AÇBØCꞇDẼ",
      "ªºÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ" + 
                "ĀāĂăĄąĆćĈĉĊċČčĎďĐđĒēĔĕĖėĘęĚěĜĝĞğĠġǄǅǆǇǈǼǽǾǿȀȁȂȃȌȍȒɰɵɲɮᴘᴤᴭᴥᵻᶅ" +
                "ᶑṆṌṕṽẄẂỚỘⅱⅲꜨꝐꞂ",
      ]
    #
    test_data.each do |s|
      #
      s_decoded = Stomp::HeaderCodec::decode(s)
      assert_equal s, s_decoded, "Sanity check decode: #{s} | #{s_decoded}"
      s_reencoded = Stomp::HeaderCodec::encode(s_decoded)
      assert_equal s_decoded, s_reencoded, "Sanity check reencode: #{s_decoded} | #{s_reencoded}"
      #
    end
  end

  # Test the basic encoding / decoding requirements.
  def test_1010_basic_encode_decode
    test_data = [
    	[ "\\\\", "\\" ],
    	["\\n", "\n"],
	    ["\\c", ":"],
	    ["\\\\\\n\\c", "\\\n:"],
	    ["\\c\\n\\\\", ":\n\\"],
	    ["\\\\\\c", "\\:"],
	    ["c\\cc", "c:c"],
	    ["n\\nn", "n\nn"],
      ]
    #
    test_data.each do |s|
      #
      s_decoded = Stomp::HeaderCodec::encode(s[0])
      assert_equal s[1], s_decoded, "Sanity check encode: #{s[1]} | #{s_decoded}"
      #
      s_encoded = Stomp::HeaderCodec::decode(s[1])
      assert_equal s[0], s_encoded, "Sanity check decode: #{s[0]} | #{s_encoded}"
    end
  end

  # Test more complex strings with the codec.
  def test_1020_fancier
    test_data = [
    	[ "a\\\\b", "a\\b" ],
      [ "\\\\\\n\\c", "\\\n:" ],
      ]
    #
    test_data.each do |s|
      #
      s_decoded = Stomp::HeaderCodec::encode(s[0])
      assert_equal s[1], s_decoded, "Sanity check encode: #{s[1]} | #{s_decoded}"
      #
      s_encoded = Stomp::HeaderCodec::decode(s[1])
      assert_equal s[0], s_encoded, "Sanity check decode: #{s[0]} | #{s_encoded}"
    end
  end

end # of class

