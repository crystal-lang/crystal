{% skip_file unless flag?(:linux) %}

require "./*"

module Syscall
  def_syscall open, Int32, filename : UInt8*, flags : Int32, mode : LibC::ModeT
  def_syscall close, Int32, fd : Int32
  def_syscall read, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  def_syscall write, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  def_syscall pipe, Int32, pipefd : Int32[2]*
  def_syscall getrandom, LibC::SSizeT, buf : UInt8*, buflen : LibC::SizeT, flags : UInt32
end
