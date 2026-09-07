{% skip_file unless flag?(:linux) && !flag?(:interpreted) %}

require "c/unistd"
require "syscall"

module Crystal::System::Syscall
  GRND_NONBLOCK = 1u32

  ::Syscall.def_syscall getrandom, LibC::SSizeT, buf : UInt8*, buflen : LibC::SizeT, flags : UInt32
  ::Syscall.def_syscall io_uring_setup, LibC::Int, entries : LibC::UInt, params : Pointer(LibC::IoUringParams)
  ::Syscall.def_syscall io_uring_enter, LibC::Int, fd : LibC::Int, to_submit : LibC::UInt, min_complete : LibC::UInt, flags : LibC::UInt, arg : Pointer(Void), nr_args : LibC::SizeT
  ::Syscall.def_syscall io_uring_register, LibC::Int, fd : LibC::Int, opcode : LibC::UInt, arg : Pointer(Void), nr_args : LibC::UInt
  ::Syscall.def_syscall sched_getaffinity, LibC::Int, pid : LibC::PidT, cpusetsize : LibC::SizeT, mask : Pointer(UInt8)
end
