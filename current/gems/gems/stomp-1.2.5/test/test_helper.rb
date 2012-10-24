# -*- encoding: utf-8 -*-

$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'test/unit'
require 'timeout'
require 'stomp'
require 'tlogger'

begin
  dummy = RUBY_ENGINE
rescue NameError => ne
  RUBY_ENGINE = "unknown"
end

=begin

  Test helper methods.

=end
module TestBase

  # Get user
  def user
    ENV['STOMP_USER'] || "guest"
  end

  # Gete passcode
  def passcode
    ENV['STOMP_PASSCODE'] || "guest"
  end

  # Get host
  def host
    ENV['STOMP_HOST'] || "localhost"
  end

  # Get port
  def port
    (ENV['STOMP_PORT'] || 61613).to_i
  end

  # Get SSL port
  def ssl_port
    (ENV['STOMP_SSLPORT'] || 61612).to_i
  end

  # Helper for minitest on 1.9
  def caller_method_name
    parse_caller(caller(2).first).last
  end

  # Helper for minitest on 1.9
  def parse_caller(at)
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file = Regexp.last_match[1]
      line = Regexp.last_match[2].to_i
      method = Regexp.last_match[3]
      method.gsub!(" ","_")
      [file, line, method]
    end
  end

  # Get a Stomp Connection.
  def get_connection()
    ch = get_conn_headers()
    conn = Stomp::Connection.open(user, passcode, host, port, false, 5, ch)
    conn
  end

  # Get a Stomp SSL Connection.
  def get_ssl_connection()
    ch = get_conn_headers()
    ssl_params = Stomp::SSLParams.new # S/B safe for all Ruby versions tested
    hash = { :hosts => [ 
      {:login => user, :passcode => passcode, :host => host, :port => ssl_port, :ssl => ssl_params},
      ],
      :connect_headers => ch
    }
    conn = Stomp::Connection.new(hash)
    conn
  end

  # Get a Stomp Client.
  def get_client()
    hash = { :hosts => [ 
          {:login => user, :passcode => passcode, :host => host, :port => port},
          ],
          :connect_headers => get_conn_headers()
        }

    client = Stomp::Client.new(hash)
    client
  end

  # Get a connection headers hash.
  def get_conn_headers()
    ch = {}
    if ENV['STOMP_TEST11']
      #
      if Stomp::SUPPORTED.index(ENV['STOMP_TEST11'])
        ch['accept-version'] = ENV['STOMP_TEST11']
      else
        ch['accept-version'] = Stomp::SPL_11
      end
      #
      ch['host'] = ENV['STOMP_RABBIT'] ? "/" : host
    end
    ch
  end

  # Subscribe to a destination.
  def conn_subscribe(dest, headers = {})
    if @conn.protocol >= Stomp::SPL_11
      headers[:id] = @conn.uuid() unless headers[:id]
    end
    @conn.subscribe dest, headers
  end

  # Get a dynamic destination name.
  def make_destination
    name = caller_method_name unless name
    qname = ENV['STOMP_DOTQUEUE'] ? "/queue/test.ruby.stomp." + name : "/queue/test/ruby/stomp/" + name
  end

end

