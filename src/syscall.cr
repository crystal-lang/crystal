# This module is only available on Linux. It provides a way to make direct system calls into the operating system.
# You most likely doesn't need this, unless you know what you are doing.
#
# For more details about Linux system calls, refer to
# [https://man7.org/linux/man-pages/man2/syscalls.2.html](https://man7.org/linux/man-pages/man2/syscalls.2.html).
@[Experimental]
module Syscall
  # Use this macro to define a system call method. Pass in the system call name, the return type and its arguments.
  # For example:
  #
  #     Syscall.def_syscall open, Int32, filename : UInt8*, flags : Int32, mode : LibC::ModeT
  #     Syscall.def_syscall close, Int32, fd : Int32
  #     Syscall.def_syscall read, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  #     Syscall.def_syscall write, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  macro def_syscall(name, return_type, *args)
    {% raise "The Syscall module is not supported on this target. It's only available for Linux." %}
  end
end

require "./syscall/*"
