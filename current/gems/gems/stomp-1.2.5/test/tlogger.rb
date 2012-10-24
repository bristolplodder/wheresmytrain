# -*- encoding: utf-8 -*-

require 'logger'	# use the standard Ruby logger .....

=begin

Callback logger for Stomp 1.1 heartbeat tests.

=end
class Tlogger

  # Initialize a callback logger class.
  def initialize(init_parms = nil)
    @log = Logger::new(STDOUT)		# User preference
    @log.level = Logger::DEBUG		# User preference
    @log.info("Logger initialization complete.")
  end

  # Log connecting events.
  def on_connecting(parms)
    begin
      @log.debug "Connecting: #{info(parms)}"
    rescue
      @log.debug "Connecting oops"
    end
  end

  # Log connected events.
  def on_connected(parms)
    begin
      @log.debug "Connected: #{info(parms)}"
    rescue
      @log.debug "Connected oops"
    end
  end

  # Log connectfail events.
  def on_connectfail(parms)
    begin
      @log.debug "Connect Fail #{info(parms)}"
    rescue
      @log.debug "Connect Fail oops"
    end
  end

  # Log disconnect events.
  def on_disconnect(parms)
    begin
      @log.debug "Disconnected #{info(parms)}"
    rescue
      @log.debug "Disconnected oops"
    end
  end

  # Log miscellaneous errors.
  def on_miscerr(parms, errstr)
    begin
      @log.debug "Miscellaneous Error #{info(parms)}"
      @log.debug "Miscellaneous Error String #{errstr}"
    rescue
      @log.debug "Miscellaneous Error oops"
    end
  end

  # Log subscribes.
  def on_subscribe(parms, headers)
    begin
      @log.debug "Subscribe Parms #{info(parms)}"
      @log.debug "Subscribe Headers #{headers}"
    rescue
      @log.debug "Subscribe oops"
    end
  end

  # Log publishes.
  def on_publish(parms, message, headers)
    begin
      @log.debug "Publish Parms #{info(parms)}"
      @log.debug "Publish Message #{message}"
      @log.debug "Publish Headers #{headers}"
    rescue
      @log.debug "Publish oops"
    end
  end

  # Log receives.
  def on_receive(parms, result)
    begin
      @log.debug "Receive Parms #{info(parms)}"
      @log.debug "Receive Result #{result}"
    rescue
      @log.debug "Receive oops"
    end
  end

  # Stomp 1.1+ - heart beat read (receive) failed
  def on_hbread_fail(parms, ticker_data)
    begin
      @log.debug "Hbreadf Parms #{info(parms)}"
      @log.debug "Hbreadf Result #{ticker_data}"
    rescue
      @log.debug "Hbreadf oops"
    end
  end

  # Stomp 1.1+ - heart beat send (transmit) failed
  def on_hbwrite_fail(parms, ticker_data)
    begin
      @log.debug "Hbwritef Parms #{info(parms)}"
      @log.debug "Hbwritef Result #{ticker_data}"
    rescue
      @log.debug "Hbwritef oops"
    end
  end


  # Stomp 1.1+ - heart beat read (receive) failed
  def on_hbread_fail(parms, ticker_data)
    begin
      @log.debug "Hbreadf Parms #{info(parms)}"
      @log.debug "Hbreadf Result #{ticker_data}"
    rescue
      @log.debug "Hbreadf oops"
    end
  end

  # Stomp 1.1+ - heart beat thread fires
  def on_hbfire(parms, type, time)
    begin
      @log.debug "HBfire #{type} " + "=" * 30
      @log.debug "HBfire #{type} Parms #{info(parms)}"
      @log.debug "HBfire #{type} Time #{time}"
    rescue
      @log.debug "HBfire #{type} oops"
    end
  end

  private

  def info(parms)
    #
    # Available in the parms Hash:
    # parms[:cur_host]
    # parms[:cur_port]
    # parms[:cur_login]
    # parms[:cur_passcode]
    # parms[:cur_ssl]
    # parms[:cur_recondelay]
    # parms[:cur_parseto]
    # parms[:cur_conattempts]
    # parms[:openstat]
    #
    "Host: #{parms[:cur_host]}, Port: #{parms[:cur_port]}, Login: #{parms[:cur_login]}, Passcode: #{parms[:cur_passcode]}" 
  end
end # of class

