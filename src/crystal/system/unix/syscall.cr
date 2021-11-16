{% skip_file unless flag?(:linux) %}

require "c/unistd"
require "syscall"

module Crystal::System::Syscall
  ::Syscall.def_syscall getrandom, LibC::SSizeT, buf : UInt8*, buflen : LibC::SizeT, flags : GetRandomFlags

  @[Flags]
  enum GetRandomFlags : UInt32
    NonBlock # Don't block and return EAGAIN instead
    Random   # No effect
    Insecure # Return non-cryptographic random bytes
  end
end
