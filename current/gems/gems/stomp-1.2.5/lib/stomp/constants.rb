# -*- encoding: utf-8 -*-

module Stomp

  # Client side
  CMD_CONNECT     = "CONNECT"
  CMD_STOMP       = "STOMP"
  CMD_DISCONNECT  = "DISCONNECT"
  CMD_SEND        = "SEND"
  CMD_SUBSCRIBE   = "SUBSCRIBE"
  CMD_UNSUBSCRIBE = "UNSUBSCRIBE"
  CMD_ACK         = "ACK"
  CMD_NACK        = "NACK"
  CMD_BEGIN       = "BEGIN"
  CMD_COMMIT      = "COMMIT"
  CMD_ABORT       = "ABORT"

  # Server side
  CMD_CONNECTED = "CONNECTED"
  CMD_MESSAGE   = "MESSAGE"
  CMD_RECEIPT   = "RECEIPT"
  CMD_ERROR     = "ERROR"

  # Protocols
  SPL_10 = "1.0"
  SPL_11 = "1.1"

  # Stomp 1.0 and 1.1
  SUPPORTED = [SPL_10, SPL_11]

  # 1.9 Encoding Name
  UTF8 = "UTF-8"
  #
  # Octet 0
  #
  NULL = "\0"
  #
  # New line
  #
  NL = "\n"
  NL_ASCII = 0x0a
  #
  # Back Slash
  #
  BACK_SLASH = "\\"
  BACK_SLASH_ASCII = 0x5c
  #
  # Literal colon
  #
  LITERAL_COLON = ":"
  COLON_ASCII = 0x3a
  #
  # Literal letter c
  #
  LITERAL_C = "c"
  C_ASCII = 0x63
  #
  # Literal letter n
  #
  LITERAL_N = "n"
  N_ASCII = 0x6e
  #
  # Codec from/to values.
  #
  ENCODE_VALUES = [
    "\\\\", "\\", # encoded, decoded
    "\\" + "n", "\n",
    "\\c", ":",
  ]

  #
  DECODE_VALUES = [
    "\\\\\\\\", "\\", # encoded, decoded
    "\\" + "n", "\n",
    "\\c", ":",
  ]

  DEFAULT_CIPHERS = [
    ["DHE-RSA-AES256-SHA", "TLSv1/SSLv3", 256, 256], 
    ["DHE-DSS-AES256-SHA", "TLSv1/SSLv3", 256, 256], 
    ["AES256-SHA", "TLSv1/SSLv3", 256, 256], 
    ["EDH-RSA-DES-CBC3-SHA", "TLSv1/SSLv3", 168, 168], 
    ["EDH-DSS-DES-CBC3-SHA", "TLSv1/SSLv3", 168, 168], 
    ["DES-CBC3-SHA", "TLSv1/SSLv3", 168, 168], 
    ["DHE-RSA-AES128-SHA", "TLSv1/SSLv3", 128, 128], 
    ["DHE-DSS-AES128-SHA", "TLSv1/SSLv3", 128, 128], 
    ["AES128-SHA", "TLSv1/SSLv3", 128, 128], 
    ["RC4-SHA", "TLSv1/SSLv3", 128, 128], 
    ["RC4-MD5", "TLSv1/SSLv3", 128, 128], 
    ["EDH-RSA-DES-CBC-SHA", "TLSv1/SSLv3", 56, 56], 
    ["EDH-DSS-DES-CBC-SHA", "TLSv1/SSLv3", 56, 56],
    ["DES-CBC-SHA", "TLSv1/SSLv3", 56, 56], 
    ["EXP-EDH-RSA-DES-CBC-SHA", "TLSv1/SSLv3", 40, 56], 
    ["EXP-EDH-DSS-DES-CBC-SHA", "TLSv1/SSLv3", 40, 56], 
    ["EXP-DES-CBC-SHA", "TLSv1/SSLv3", 40, 56], 
    ["EXP-RC2-CBC-MD5", "TLSv1/SSLv3", 40, 128], 
    ["EXP-RC4-MD5", "TLSv1/SSLv3", 40, 128],
  ]

end
