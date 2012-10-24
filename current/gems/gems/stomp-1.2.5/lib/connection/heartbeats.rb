# -*- encoding: utf-8 -*-

require 'socket'
require 'timeout'
require 'io/wait'
require 'digest/sha1'

module Stomp

  class Connection

    private

    def _validate_hbheader()
      return if @connect_headers[:"heart-beat"] == "0,0" # Caller does not want heartbeats.  OK.
      parts = @connect_headers[:"heart-beat"].split(",")
      if (parts.size != 2) || (parts[0] != parts[0].to_i.to_s) || (parts[1] != parts[1].to_i.to_s)
        raise Stomp::Error::InvalidHeartBeatHeaderError
      end
    end

    def _init_heartbeats()
      return if @connect_headers[:"heart-beat"] == "0,0" # Caller does not want heartbeats.  OK.

      # Init.

      #
      @cx = @cy = @sx = @sy = 0, # Variable names as in spec

      #
      @hbsend_interval = @hbrecv_interval = 0.0 # Send/Receive ticker interval.

      #
      @hbsend_count = @hbrecv_count = 0 # Send/Receive ticker counts.

      #
      @ls = @lr = -1.0 # Last send/receive time (from Time.now.to_f)

      #
      @st = @rt = nil # Send/receive ticker thread

      # Handle current client / server capabilities.

      #
      cfh = @connection_frame.headers.symbolize_keys
      return if cfh[:"heart-beat"] == "0,0" # Server does not want heartbeats

      # Conect header parts.
      parts = @connect_headers[:"heart-beat"].split(",")
      @cx = parts[0].to_i
      @cy = parts[1].to_i

      # Connected frame header parts.
      parts = cfh[:"heart-beat"].split(",")
      @sx = parts[0].to_i
      @sy = parts[1].to_i

      # Catch odd situations like server has used => heart-beat:000,00000
      return if (@cx == 0 && @cy == 0) || (@sx == 0 && @sy == 0)

      # See if we are doing anything at all.

      #
      @hbs = @hbr = true # Sending/Receiving heartbeats. Assume yes at first.
      # Check if sending is possible.
      @hbs = false if @cx == 0 || @sy == 0
      # Check if receiving is possible.
      @hbr = false if @sx == 0 || @cy == 0
      # Should not do heartbeats at all
      return if (!@hbs && !@hbr)

      # If sending
      if @hbs
        sm = @cx >= @sy ? @cx : @sy     # ticker interval, ms
        @hbsend_interval = 1000.0 * sm  # ticker interval, μs
        @ls = Time.now.to_f             # best guess at start
        _start_send_ticker()
      end

      # If receiving
      if @hbr
        rm = @sx >= @cy ? @sx : @cy     # ticker interval, ms
        @hbrecv_interval = 1000.0 * rm  # ticker interval, μs
        @lr = Time.now.to_f             # best guess at start
        _start_receive_ticker()
      end

    end

    # _start_send_ticker starts a thread to send heartbeats when required.
    def _start_send_ticker()
      sleeptime = @hbsend_interval / 1000000.0 # Sleep time secs
      @st = Thread.new {
        while true do
          sleep sleeptime
          curt = Time.now.to_f
          if @logger && @logger.respond_to?(:on_hbfire)
            @logger.on_hbfire(log_params, "send_fire", curt)
          end
          delta = curt - @ls
          if delta > (@hbsend_interval - (@hbsend_interval/5.0)) / 1000000.0 # Be tolerant (minus)
            if @logger && @logger.respond_to?(:on_hbfire)
              @logger.on_hbfire(log_params, "send_heartbeat", curt)
            end
            # Send a heartbeat
            @transmit_semaphore.synchronize do
              begin
                @socket.puts
                @ls = curt      # Update last send
                @hb_sent = true # Reset if necessary
                @hbsend_count += 1
              rescue Exception => sendex
                @hb_sent = false # Set the warning flag
                if @logger && @logger.respond_to?(:on_hbwrite_fail)
                  @logger.on_hbwrite_fail(log_params, {"ticker_interval" => @hbsend_interval,
                  "exception" => sendex})
                end
                raise # Re-raise.  What else could be done here?
              end
            end
          end
          Thread.pass
        end
      }
    end

    # _start_receive_ticker starts a thread that receives heartbeats when required.
    def _start_receive_ticker()
      sleeptime = @hbrecv_interval / 1000000.0 # Sleep time secs
      @rt = Thread.new {
        while true do
          sleep sleeptime
          curt = Time.now.to_f
          if @logger && @logger.respond_to?(:on_hbfire)
            @logger.on_hbfire(log_params, "receive_fire", curt)
          end
          delta = curt - @lr
          if delta > ((@hbrecv_interval + (@hbrecv_interval/5.0)) / 1000000.0) # Be tolerant (plus)
            if @logger && @logger.respond_to?(:on_hbfire)
              @logger.on_hbfire(log_params, "receive_heartbeat", curt)
            end
            # Client code could be off doing something else (that is, no reading of
            # the socket has been requested by the caller).  Try to  handle that case.
            lock = @read_semaphore.try_lock
            if lock
              last_char = @socket.getc
              plc = parse_char(last_char)
              if plc == "\n" # Server Heartbeat
                @lr = Time.now.to_f
              else
                @socket.ungetc(last_char)
              end
              @read_semaphore.unlock
              @hbrecv_count += 1
            else
              # Shrug.  Have not received one.  Just set warning flag.
              @hb_received = false
              if @logger && @logger.respond_to?(:on_hbread_fail)
                @logger.on_hbread_fail(log_params, {"ticker_interval" => @hbrecv_interval})
              end
            end
          else
            @hb_received = true # Reset if necessary
          end
          Thread.pass
        end
      }
    end

  end # class

end # module

