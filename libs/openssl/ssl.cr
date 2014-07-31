require "lib_ssl"

LibSSL.ssl_load_error_strings
LibSSL.ssl_library_init

require "ssl/*"
