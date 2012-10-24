# -*- encoding: utf-8 -*-

#
# Reference: https://github.com/stompgem/stomp/wiki/extended-ssl-overview
#
require "rubygems"
require "stomp"
#
# == SSL Use Case 4 - server *does* authenticate client, client *does* authenticate server
#
# Subcase 4.A - Message broker configuration does *not* require client authentication
#
# - Expect connection success
# - Expect a verify result of 0 becuase the client did authenticate the
#   server's certificate.
#
# Subcase 4.B - Message broker configuration *does* require client authentication
#
# - Expect connection success if the server can authenticate the client certificate
# - Expect a verify result of 0 because the client did authenticate the
#   server's certificate.
#
class ExampleSSL4
  # Initialize.
  def initialize
  end
  # Run example.
  def run
    ssl_opts = Stomp::SSLParams.new(:key_file => "/home/gmallard/sslwork/twocas_tj/clientCA/ClientTJ.key",
    :cert_file => "/home/gmallard/sslwork/twocas_tj/clientCA/ClientTJ.crt",
    :ts_files => "/home/gmallard/sslwork/twocas_tj/serverCA/ServerTJCA.crt")
    #
    hash = { :hosts => [
        {:login => 'guest', :passcode => 'guest', :host => 'localhost', :port => 61612, :ssl => ssl_opts},
      ],
      :reliable => false, # YMMV, to test this in a sane manner
    }
    #
    puts "Connect starts, SSL Use Case 4"
    c = Stomp::Connection.new(hash)
    puts "Connect completed"
    puts "SSL Verify Result: #{ssl_opts.verify_result}"
    # puts "SSL Peer Certificate:\n#{ssl_opts.peer_cert}"
    c.disconnect
  end
end
#
e = ExampleSSL4.new
e.run

