# -*- encoding: utf-8 -*-

require 'socket'
require 'timeout'
require 'io/wait'
require 'digest/sha1'

module Stomp

  class Connection

    private

    # Support multi-homed servers.  
    def _expand_hosts(hash)
      new_hash = hash.clone
      new_hash[:hosts_cloned] = hash[:hosts].clone
      new_hash[:hosts] = []
      #
      hash[:hosts].each do |host_parms|
        ai = Socket.getaddrinfo(host_parms[:host], nil, nil, Socket::SOCK_STREAM)
        next if ai.nil? || ai.size == 0
        info6 = ai.detect {|info| info[4] == Socket::AF_INET6}
        info4 = ai.detect {|info| info[4] == Socket::AF_INET}
        if info6
          new_hostp = host_parms.clone
          new_hostp[:host] = info6[3]
          new_hash[:hosts] << new_hostp
        end
        if info4
          new_hostp = host_parms.clone
          new_hostp[:host] = info4[3]
          new_hash[:hosts] << new_hostp
        end
      end
      return new_hash
    end

    # Handle 1.9+ character representation.
    def parse_char(char)
      RUBY_VERSION > '1.9' ? char : char.chr
    end

    # Create parameters for any callback logger.
    def log_params()
      lparms = @parameters.clone if @parameters
      lparms = {} unless lparms
      lparms[:cur_host] = @host
      lparms[:cur_port] = @port
      lparms[:cur_login] = @login
      lparms[:cur_passcode] = @passcode
      lparms[:cur_ssl] = @ssl
      lparms[:cur_recondelay] = @reconnect_delay
      lparms[:cur_parseto] = @parse_timeout
      lparms[:cur_conattempts] = @connection_attempts
      lparms[:openstat] = open?
      #
      lparms
    end

    # _pre_connect handles low level logic just prior to a physical connect.
    def _pre_connect()
      @connect_headers = @connect_headers.symbolize_keys
      raise Stomp::Error::ProtocolErrorConnect if (@connect_headers[:"accept-version"] && !@connect_headers[:host])
      raise Stomp::Error::ProtocolErrorConnect if (!@connect_headers[:"accept-version"] && @connect_headers[:host])
      return unless (@connect_headers[:"accept-version"] && @connect_headers[:host]) # 1.0
      # Try 1.1 or greater
      okvers = []
      avers = @connect_headers[:"accept-version"].split(",")
      avers.each do |nver|
        if Stomp::SUPPORTED.index(nver)
          okvers << nver
        end
      end
      raise Stomp::Error::UnsupportedProtocolError if okvers == []
      @connect_headers[:"accept-version"] = okvers.join(",") # This goes to server
      # Heartbeats - pre connect
      return unless @connect_headers[:"heart-beat"]
      _validate_hbheader()
    end

    # _post_connect handles low level logic just post a physical connect.
    def _post_connect()
      return unless (@connect_headers[:"accept-version"] && @connect_headers[:host])
      return if @connection_frame.command == Stomp::CMD_ERROR
      # We are CONNECTed
      cfh = @connection_frame.headers.symbolize_keys
      @protocol = cfh[:version]
      if @protocol
        # Should not happen, but check anyway
        raise Stomp::Error::UnsupportedProtocolError unless Stomp::SUPPORTED.index(@protocol)
      else # CONNECTed to a 1.0 server that does not return *any* 1.1 type headers
        @protocol = Stomp::SPL_10 # reset
        return
      end
      # Heartbeats
      return unless @connect_headers[:"heart-beat"]
      _init_heartbeats()
    end

  end # class

end # module

