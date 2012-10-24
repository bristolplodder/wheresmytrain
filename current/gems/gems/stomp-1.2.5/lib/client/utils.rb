# -*- encoding: utf-8 -*-

require 'thread'
require 'digest/sha1'

module Stomp

  class Client

    private

    # Set a subscription id in the headers hash if one does not already exist.
    # For simplicities sake, all subscriptions have a subscription ID.
    # setting an id in the SUBSCRIPTION header is described in the stomp protocol docs:
    # http://stomp.github.com/
    def set_subscription_id_if_missing(destination, headers)
      headers[:id] = headers[:id] ? headers[:id] : headers['id']
      if headers[:id] == nil
        headers[:id] = Digest::SHA1.hexdigest(destination)
      end
    end

    # Register a receipt listener.
    def register_receipt_listener(listener)
      id = -1
      @id_mutex.synchronize do
        id = @ids.to_s
        @ids = @ids.succ
      end
      @receipt_listeners[id] = listener
      id
    end

    # url_regex defines a regex for e.g. login:passcode@host:port or host:port
    def url_regex
      '(([\w\.\-]*):(\w*)@)?([\w\.\-]+):(\d+)'
    end

    # Parse a stomp URL.
    def parse_hosts(url)
      hosts = []

      host_match = /stomp(\+ssl)?:\/\/(([\w\.]*):(\w*)@)?([\w\.]+):(\d+)\)/
      url.scan(host_match).each do |match|
        host = {}
        host[:ssl] = !match[0].nil?
        host[:login] =  match[2] || ""
        host[:passcode] = match[3] || ""
        host[:host] = match[4]
        host[:port] = match[5].to_i

        hosts << host
      end

      hosts
    end

    # A very basic check of required arguments.
    # *NOTE* This method will be made private in the next release.
    def check_arguments!()
      raise ArgumentError if @host.nil? || @host.empty?
      raise ArgumentError if @port.nil? || @port == '' || @port < 1 || @port > 65535
      raise ArgumentError unless @reliable.is_a?(TrueClass) || @reliable.is_a?(FalseClass)
    end

    # filter_options returns a new Hash of filtered options.
    def filter_options(options)
      new_options = {}
      new_options[:initial_reconnect_delay] = (options["initialReconnectDelay"] || 10).to_f / 1000 # In ms
      new_options[:max_reconnect_delay] = (options["maxReconnectDelay"] || 30000 ).to_f / 1000 # In ms
      new_options[:use_exponential_back_off] = !(options["useExponentialBackOff"] == "false") # Default: true
      new_options[:back_off_multiplier] = (options["backOffMultiplier"] || 2 ).to_i
      new_options[:max_reconnect_attempts] = (options["maxReconnectAttempts"] || 0 ).to_i
      new_options[:randomize] = options["randomize"] == "true" # Default: false
      new_options[:backup] = false # Not implemented yet: I'm using a master X slave solution
      new_options[:timeout] = -1 # Not implemented yet: a "timeout(5) do ... end" would do the trick, feel free

      new_options
    end

    # find_listener returns the listener for a given subscription in a given message.
    def find_listener(message)
      subscription_id = message.headers['subscription']
      if subscription_id == nil
        # For backward compatibility, some messages may already exist with no
        # subscription id, in which case we can attempt to synthesize one.
        set_subscription_id_if_missing(message.headers['destination'], message.headers)
        subscription_id = message.headers[:id]
      end
      @listeners[subscription_id]
    end

    # Start a single listener thread.  Misnamed I think.
    def start_listeners()
      @listeners = {}
      @receipt_listeners = {}
      @replay_messages_by_txn = {}

      @listener_thread = Thread.start do
        while true
          message = @connection.receive
          if message.command == Stomp::CMD_MESSAGE
            if listener = find_listener(message)
              listener.call(message)
            end
          elsif message.command == Stomp::CMD_RECEIPT
            if listener = @receipt_listeners[message.headers['receipt-id']]
              listener.call(message)
            end
          end
        end
      end
    end
  end
end

