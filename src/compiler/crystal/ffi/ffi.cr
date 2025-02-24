{% skip_file if flag?(:without_ffi) %}
require "./lib_ffi"
require "./type"
require "./call_interface"
require "./closure"

# :nodoc:
module Crystal::FFI
end
