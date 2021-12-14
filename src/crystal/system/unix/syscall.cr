{% skip_file unless flag?(:linux) && !flag?(:interpreted) %}

require "c/unistd"
require "syscall"

module Crystal::System::Syscall
  ::Syscall.def_syscall getrandom, LibC::SSizeT, buf : UInt8*, buflen : LibC::SizeT, flags : UInt32
end
