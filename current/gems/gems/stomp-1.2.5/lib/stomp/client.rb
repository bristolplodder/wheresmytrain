# -*- encoding: utf-8 -*-

require 'thread'
require 'digest/sha1'

module Stomp

  # Typical Stomp client class. Uses a listener thread to receive frames
  # from the server, any thread can send.
  #
  # Receives all happen in one thread, so consider not doing much processing
  # in that thread if you have much message volume.
  class Client

    public

    # The login ID used by the client.
    attr_reader :login

    # The login credentials used by the client.
    attr_reader :passcode

    # The Stomp host specified by the client.
    attr_reader :host

    # The Stomp host's listening port.
    attr_reader :port

    # Is this connection reliable?
    attr_reader :reliable

    # Parameters Hash, possibly nil for a non-hashed connect.
    attr_reader :parameters

    # A new Client object can be initialized using three forms:
    #
    # Hash (this is the recommended Client initialization method):
    #
    #   hash = {
    #     :hosts => [
    #       {:login => "login1", :passcode => "passcode1", :host => "localhost", :port => 61616, :ssl => false},
    #       {:login => "login2", :passcode => "passcode2", :host => "remotehost", :port => 61617, :ssl => false}
    #     ],
    #     :reliable => true,
    #     :initial_reconnect_delay => 0.01,
    #     :max_reconnect_delay => 30.0,
    #     :use_exponential_back_off => true,
    #     :back_off_multiplier => 2,
    #     :max_reconnect_attempts => 0,
    #     :randomize => false,
    #     :backup => false,
    #     :connect_timeout => 0,
    #     :connect_headers => {},
    #     :parse_timeout => 5,
    #     :logger => nil,
    #   }
    #
    #   e.g. c = Stomp::Client.new(hash)
    #
    # Positional parameters:
    #   login     (String,  default : '')
    #   passcode  (String,  default : '')
    #   host      (String,  default : 'localhost')
    #   port      (Integer, default : 61613)
    #   reliable  (Boolean, default : false)
    #
    #   e.g. c = Stomp::Client.new('login', 'passcode', 'localhost', 61613, true)
    #
    # Stomp URL :
    #   A Stomp URL must begin with 'stomp://' and can be in one of the following forms:
    #
    #   stomp://host:port
    #   stomp://host.domain.tld:port
    #   stomp://login:passcode@host:port
    #   stomp://login:passcode@host.domain.tld:port
    #
    #   e.g. c = Stomp::Client.new(urlstring)
    #
    def initialize(login = '', passcode = '', host = 'localhost', port = 61613, reliable = false, autoflush = false)

      # Parse stomp:// URL's or set params
      if login.is_a?(Hash)
        @parameters = login

        first_host = @parameters[:hosts][0]

        @login = first_host[:login]
        @passcode = first_host[:passcode]
        @host = first_host[:host]
        @port = first_host[:port] || Connection::default_port(first_host[:ssl])

        @reliable = true
      elsif login =~ /^stomp:\/\/#{url_regex}/ # e.g. stomp://login:passcode@host:port or stomp://host:port
        @login = $2 || ""
        @passcode = $3 || ""
        @host = $4
        @port = $5.to_i
        @reliable = false
      elsif login =~ /^failover:(\/\/)?\(stomp(\+ssl)?:\/\/#{url_regex}(,stomp(\+ssl)?:\/\/#{url_regex}\))+(\?(.*))?$/ 
        # e.g. failover://(stomp://login1:passcode1@localhost:61616,stomp://login2:passcode2@remotehost:61617)?option1=param
        first_host = {}
        first_host[:ssl] = !$2.nil?
        @login = first_host[:login] = $4 || ""
        @passcode = first_host[:passcode] = $5 || ""
        @host = first_host[:host] = $6
        @port = first_host[:port] = $7.to_i || Connection::default_port(first_host[:ssl])

        options = $16 || ""
        parts = options.split(/&|=/)
        options = Hash[*parts]

        hosts = [first_host] + parse_hosts(login)

        @parameters = {}
        @parameters[:hosts] = hosts

        @parameters.merge! filter_options(options)

        @reliable = true
      else
        @login = login
        @passcode = passcode
        @host = host
        @port = port.to_i
        @reliable = reliable
      end

      check_arguments!()

      @id_mutex = Mutex.new()
      @ids = 1

      if @parameters
        @connection = Connection.new(@parameters)
      else
        @connection = Connection.new(@login, @passcode, @host, @port, @reliable)
        @connection.autoflush = autoflush
      end

      start_listeners()

    end

    # open is syntactic sugar for 'Client.new' See 'initialize' for usage.
    def self.open(login = '', passcode = '', host = 'localhost', port = 61613, reliable = false)
      Client.new(login, passcode, host, port, reliable)
    end

    # join the listener thread for this client,
    # generally used to wait for a quit signal.
    def join(limit = nil)
      @listener_thread.join(limit)
    end

    # Begin starts work in a a transaction by name.
    def begin(name, headers = {})
      @connection.begin(name, headers)
    end

    # Abort aborts work in a transaction by name.
    def abort(name, headers = {})
      @connection.abort(name, headers)

      # lets replay any ack'd messages in this transaction
      replay_list = @replay_messages_by_txn[name]
      if replay_list
        replay_list.each do |message|
          if listener = find_listener(message)
            listener.call(message)
          end
        end
      end
    end

    # Commit commits work in a transaction by name.
    def commit(name, headers = {})
      txn_id = headers[:transaction]
      @replay_messages_by_txn.delete(txn_id)
      @connection.commit(name, headers)
    end

    # Subscribe to a destination, must be passed a block
    # which will be used as a callback listener.
    # Accepts a transaction header ( :transaction => 'some_transaction_id' ).
    def subscribe(destination, headers = {})
      raise "No listener given" unless block_given?
      # use subscription id to correlate messages to subscription. As described in
      # the SUBSCRIPTION section of the protocol: http://stomp.github.com/.
      # If no subscription id is provided, generate one.
      set_subscription_id_if_missing(destination, headers)
      if @listeners[headers[:id]]
        raise "attempting to subscribe to a queue with a previous subscription"
      end
      @listeners[headers[:id]] = lambda {|msg| yield msg}
      @connection.subscribe(destination, headers)
    end

    # Unsubscribe from a subscription by name.
    def unsubscribe(name, headers = {})
      set_subscription_id_if_missing(name, headers)
      @connection.unsubscribe(name, headers)
      @listeners[headers[:id]] = nil
    end

    # Acknowledge a message, used when a subscription has specified
    # client acknowledgement ( connection.subscribe("/queue/a",{:ack => 'client'}).
    # Accepts a transaction header ( :transaction => 'some_transaction_id' ).
    def acknowledge(message, headers = {})
      txn_id = headers[:transaction]
      if txn_id
        # lets keep around messages ack'd in this transaction in case we rollback
        replay_list = @replay_messages_by_txn[txn_id]
        if replay_list.nil?
          replay_list = []
          @replay_messages_by_txn[txn_id] = replay_list
        end
        replay_list << message
      end
      if block_given?
        headers['receipt'] = register_receipt_listener lambda {|r| yield r}
      end
      @connection.ack(message.headers['message-id'], headers)
    end

    # Stomp 1.1+ NACK.
    def nack(message_id, headers = {})
      @connection.nack(message_id, headers)
    end

    # Unreceive a message, sending it back to its queue or to the DLQ.
    def unreceive(message, options = {})
      @connection.unreceive(message, options)
    end

    # Publishes message to destination.
    # If a block is given a receipt will be requested and passed to the
    # block on receipt.
    # Accepts a transaction header ( :transaction => 'some_transaction_id' ).
    def publish(destination, message, headers = {})
      if block_given?
        headers['receipt'] = register_receipt_listener lambda {|r| yield r}
      end
      @connection.publish(destination, message, headers)
    end

    # :TODO: This should not be used.  Currently only referenced in the 
    # spec tests.
    # *NOTE* This will be removed in the next release.
    def obj_send(*args)
      __send__(*args)
    end

    # Return the broker's CONNECTED frame to the client.  Misnamed.
    def connection_frame()
      @connection.connection_frame
    end

    # Return any RECEIPT frame received by DISCONNECT.
    def disconnect_receipt()
      @connection.disconnect_receipt
    end

    # open? tests if this client connection is open.
    def open?
      @connection.open?()
    end

    # close? tests if this client connection is closed.
    def closed?()
      @connection.closed?()
    end

    # close frees resources in use by this client.  The listener thread is
    # terminated, and disconnect on the connection is called.
    def close(headers={})
      @listener_thread.exit
      @connection.disconnect(headers)
    end

    # running checks if the thread was created and is not dead.
    def running()
      @listener_thread && !!@listener_thread.status
    end

    # set_logger identifies a new callback logger.
    def set_logger(logger)
      @connection.set_logger(logger)
    end

    # protocol returns the current client's protocol level.
    def protocol()
      @connection.protocol()
    end

    # valid_utf8? validates any given string for UTF8 compliance.
    def valid_utf8?(s)
      @connection.valid_utf8?(s)
    end

    # sha1 returns a SHA1 sum of a given string.
    def sha1(data)
      @connection.sha1(data)
    end

    # uuid returns a type 4 UUID.
    def uuid()
      @connection.uuid()
    end

    # hbsend_interval returns the connection's heartbeat send interval.
    def hbsend_interval()
      @connection.hbsend_interval()
    end

    # hbrecv_interval returns the connection's heartbeat receive interval.
    def hbrecv_interval()
      @connection.hbrecv_interval()
    end

    # hbsend_count returns the current connection's heartbeat send count.
    def hbsend_count()
      @connection.hbsend_count()
    end

    # hbrecv_count returns the current connection's heartbeat receive count.
    def hbrecv_count()
      @connection.hbrecv_count()
    end

    # Poll for asynchronous messages issued by broker.
    # Return nil of no message available, else the message
    def poll()
      @connection.poll()
    end

    # autoflush= sets the current connection's autoflush setting.
    def autoflush=(af)
      @connection.autoflush = af
    end

    # autoflush returns the current connection's autoflush setting.
    def autoflush()
      @connection.autoflush()
    end

  end # Class

end # Module

