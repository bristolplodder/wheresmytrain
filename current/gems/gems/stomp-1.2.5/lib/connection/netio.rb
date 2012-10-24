# -*- encoding: utf-8 -*-

require 'socket'
require 'timeout'
require 'io/wait'
require 'digest/sha1'

module Stomp

  class Connection

    private

    # Really read from the wire.
    def _receive(read_socket)
      @read_semaphore.synchronize do
        line = ''
        if @protocol == Stomp::SPL_10 || (@protocol >= Stomp::SPL_11 && !@hbr)
          line = read_socket.gets # The old way
        else # We are >= 1.1 *AND* receiving heartbeats.
          while true
            line = read_socket.gets # Data from wire
            break unless line == "\n"
            line = ''
            @lr = Time.now.to_f
          end
        end
        return nil if line.nil?
        # If the reading hangs for more than X seconds, abort the parsing process.
        # X defaults to 5.  Override allowed in connection hash parameters.
        Timeout::timeout(@parse_timeout, Stomp::Error::PacketParsingTimeout) do
          # Reads the beginning of the message until it runs into a empty line
          message_header = ''
          begin
            message_header += line
            line = read_socket.gets
            raise Stomp::Error::StompServerError if line.nil?
          end until line =~ /^\s?\n$/

          # Checks if it includes content_length header
          content_length = message_header.match /content-length\s?:\s?(\d+)\s?\n/
          message_body = ''

          # If content_length is present, read the specified amount of bytes
          if content_length
            message_body = read_socket.read content_length[1].to_i
            raise Stomp::Error::InvalidMessageLength unless parse_char(read_socket.getc) == "\0"
            # Else read the rest of the message until the first \0
          else
            message_body = read_socket.readline("\0")
            message_body.chop!
          end

          # If the buffer isn't empty, reads trailing new lines.
          #
          # Note: experiments with JRuby seem to show that .ready? never
          # returns true.  This means that this code to drain trailing new
          # lines never runs using JRuby.
          #
          # Note 2: the draining of new lines must be done _after_ a message
          # is read.  Do _not_ leave them on the wire and attempt to drain them
          # at the start of the next read.  Attempting to do that breaks the
          # asynchronous nature of the 'poll' method.
          while read_socket.ready?
            last_char = read_socket.getc
            break unless last_char
            if parse_char(last_char) != "\n"
              read_socket.ungetc(last_char)
              break
            end
          end
          # And so, a JRuby hack.  Remove any new lines at the start of the
          # next buffer.
          message_header.gsub!(/^\n?/, "")

          if @protocol >= Stomp::SPL_11
            @lr = Time.now.to_f if @hbr
          end
          # Adds the excluded \n and \0 and tries to create a new message with it
          msg = Message.new(message_header + "\n" + message_body + "\0", @protocol >= Stomp::SPL_11)
          #
          if @protocol >= Stomp::SPL_11 && msg.command != Stomp::CMD_CONNECTED
            msg.headers = _decodeHeaders(msg.headers)
          end
          msg
        end
      end
    end

    # transmit logically puts a Message on the wire.
    def transmit(command, headers = {}, body = '')
      # The transmit may fail so we may need to retry.
      while TRUE
        begin
          used_socket = socket
          _transmit(used_socket, command, headers, body)
          return
        rescue Stomp::Error::MaxReconnectAttempts => e
          raise
        rescue
          @failure = $!
          raise unless @reliable
          errstr = "transmit to #{@host} failed: #{$!}\n"
          if @logger && @logger.respond_to?(:on_miscerr)
            @logger.on_miscerr(log_params, errstr)
          else
            $stderr.print errstr
          end
        end
      end
    end

    # _transmit is the real wire write logic.
    def _transmit(used_socket, command, headers = {}, body = '')
      if @protocol >= Stomp::SPL_11 && command != Stomp::CMD_CONNECT
        headers = _encodeHeaders(headers)
      end
      @transmit_semaphore.synchronize do
        # Handle nil body
        body = '' if body.nil?
        # The content-length should be expressed in bytes.
        # Ruby 1.8: String#length => # of bytes; Ruby 1.9: String#length => # of characters
        # With Unicode strings, # of bytes != # of characters.  So, use String#bytesize when available.
        body_length_bytes = body.respond_to?(:bytesize) ? body.bytesize : body.length

        # ActiveMQ interprets every message as a BinaryMessage
        # if content_length header is included.
        # Using :suppress_content_length => true will suppress this behaviour
        # and ActiveMQ will interpret the message as a TextMessage.
        # For more information refer to http://juretta.com/log/2009/05/24/activemq-jms-stomp/
        # Lets send this header in the message, so it can maintain state when using unreceive
        headers[:'content-length'] = "#{body_length_bytes}" unless headers[:suppress_content_length]
        headers[:'content-type'] = "text/plain; charset=UTF-8" unless headers[:'content-type']
        used_socket.puts command
        headers.each do |k,v|
          if v.is_a?(Array)
            v.each do |e|
              used_socket.puts "#{k}:#{e}"
            end
          else
            used_socket.puts "#{k}:#{v}"
          end
        end
        used_socket.puts
        used_socket.write body
        used_socket.write "\0"
        used_socket.flush if autoflush

        if @protocol >= Stomp::SPL_11
          @ls = Time.now.to_f if @hbs
        end

      end
    end

    # open_tcp_socket opens a TCP socket.
    def open_tcp_socket()
      tcp_socket = nil

      if @logger && @logger.respond_to?(:on_connecting)
        @logger.on_connecting(log_params)
      end

      Timeout::timeout(@connect_timeout, Stomp::Error::SocketOpenTimeout) do
        tcp_socket = TCPSocket.open(@host, @port)
      end

      tcp_socket
    end

    # open_ssl_socket opens an SSL socket.
    def open_ssl_socket()
      require 'openssl' unless defined?(OpenSSL)
      begin # Any raised SSL exceptions
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE # Assume for now
        #
        # Note: if a client uses :ssl => true this results in the gem using
        # the _default_ Ruby ciphers list.  This is _known_ to fail in later
        # Ruby releases.  The gem provides a default cipher list that may
        # function in these cases.  To use this connect with:
        # * :ssl => Stomp::SSLParams.new
        # * :ssl => Stomp::SSLParams.new(..., :ciphers => Stomp::DEFAULT_CIPHERS)
        #
        # If connecting with an SSLParams instance, and the _default_ Ruby
        # ciphers list is required, use:
        # * :ssl => Stomp::SSLParams.new(..., :use_ruby_ciphers => true)
        #
        # If a custom ciphers list is required, connect with:
        # * :ssl => Stomp::SSLParams.new(..., :ciphers => custom_ciphers_list)
        #
        if @ssl != true
          #
          # Here @ssl is:
          # * an instance of Stomp::SSLParams
          # Control would not be here if @ssl == false or @ssl.nil?.
          #

          # Back reference the SSLContext
          @ssl.ctx = ctx

          # Server authentication parameters if required
          if @ssl.ts_files
            ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
            truststores = OpenSSL::X509::Store.new
            fl = @ssl.ts_files.split(",")
            fl.each do |fn|
              # Add next cert file listed
              raise Stomp::Error::SSLNoTruststoreFileError if !File::exists?(fn)
              raise Stomp::Error::SSLUnreadableTruststoreFileError if !File::readable?(fn)
              truststores.add_file(fn)
            end
            ctx.cert_store = truststores
          end

          # Client authentication parameters.
          # Both cert file and key file must be present or not, it can not be a mix.
          raise Stomp::Error::SSLClientParamsError if @ssl.cert_file.nil? && !@ssl.key_file.nil?
          raise Stomp::Error::SSLClientParamsError if !@ssl.cert_file.nil? && @ssl.key_file.nil?
          if @ssl.cert_file # Any check will do here
            raise Stomp::Error::SSLNoCertFileError if !File::exists?(@ssl.cert_file)
            raise Stomp::Error::SSLUnreadableCertFileError if !File::readable?(@ssl.cert_file)
            ctx.cert = OpenSSL::X509::Certificate.new(File.read(@ssl.cert_file))
            raise Stomp::Error::SSLNoKeyFileError if !File::exists?(@ssl.key_file)
            raise Stomp::Error::SSLUnreadableKeyFileError if !File::readable?(@ssl.key_file)
            ctx.key  = OpenSSL::PKey::RSA.new(File.read(@ssl.key_file), @ssl.key_password)
          end

          # Cipher list
          if !@ssl.use_ruby_ciphers # No Ruby ciphers (the default)
            if @ssl.ciphers # User ciphers list?
              ctx.ciphers = @ssl.ciphers # Accept user supplied ciphers
            else
              ctx.ciphers = Stomp::DEFAULT_CIPHERS # Just use Stomp defaults
            end
          end
        end

        #
        ssl = nil
        if @logger && @logger.respond_to?(:on_ssl_connecting)
          @logger.on_ssl_connecting(log_params)
        end

        Timeout::timeout(@connect_timeout, Stomp::Error::SocketOpenTimeout) do
          ssl = OpenSSL::SSL::SSLSocket.new(open_tcp_socket, ctx)
        end
        def ssl.ready?
          ! @rbuffer.empty? || @io.ready?
        end
        ssl.connect
        if @ssl != true
          # Pass back results if possible
          if RUBY_VERSION =~ /1\.8\.[56]/
            @ssl.verify_result = "N/A for Ruby #{RUBY_VERSION}"
          else
            @ssl.verify_result = ssl.verify_result
          end
          @ssl.peer_cert = ssl.peer_cert
        end
        if @logger && @logger.respond_to?(:on_ssl_connected)
          @logger.on_ssl_connected(log_params)
        end
        ssl
      rescue Exception => ex
        if @logger && @logger.respond_to?(:on_ssl_connectfail)
          lp = log_params.clone
          lp[:ssl_exception] = ex
          @logger.on_ssl_connectfail(lp)
        end
        #
        raise # Reraise
      end
    end

    # close_socket closes the current open socket, and hence the connection.
    def close_socket()
      begin
        # Need to set @closed = true before closing the socket
        # within the @read_semaphore thread
        @closed = true
        @read_semaphore.synchronize do
          @socket.close
        end
      rescue
        #Ignoring if already closed
      end
      @closed
    end

    # open_socket opens a TCP or SSL soclet as required.
    def open_socket()
      used_socket = @ssl ? open_ssl_socket : open_tcp_socket
      # try to close the old connection if any
      close_socket

      @closed = false
      # Use keepalive
      used_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
      used_socket
    end

    # connect performs a basic STOMP CONNECT operation.
    def connect(used_socket)
      @connect_headers = {} unless @connect_headers # Caller said nil/false
      headers = @connect_headers.clone
      headers[:login] = @login
      headers[:passcode] = @passcode
      _pre_connect
      _transmit(used_socket, "CONNECT", headers)
      @connection_frame = _receive(used_socket)
      _post_connect
      @disconnect_receipt = nil
      @session = @connection_frame.headers["session"] if @connection_frame
      # replay any subscriptions.
      @subscriptions.each { |k,v| _transmit(used_socket, Stomp::CMD_SUBSCRIBE, v) }
    end

  end # class

end # module

