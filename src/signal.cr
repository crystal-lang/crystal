lib LibC
  fun signal(sig : Int32, handler : Int32 ->)
end

module Signal
  extend self

  EXIT   =  0
  HUP    =  1
  INT    =  2
  QUIT   =  3
  ILL    =  4
  TRAP   =  5
  IOT    =  6
  ABRT   =  6
  EMT    =  7
  FPE    =  8
  KILL   =  9
  BUS    = 10
  SEGV   = 11
  SYS    = 12
  PIPE   = 13
  ALRM   = 15
  TERM   = 15
  URG    = 16
  STOP   = 17
  TSTP   = 18
  CONT   = 19
  CHLD   = 20
  CLD    = 20
  TTIN   = 21
  TTOU   = 22
  IO     = 23
  XCPU   = 24
  XFSZ   = 25
  VTLARM = 26
  PROF   = 27
  WINCH  = 28
  INFO   = 29
  USR1   = 30
  USR2   = 31

  def trap(signal, &block : Int32 ->)
    handlers = @@handlers ||= {} of Int32 => Int32 ->
    handlers[signal] = block
    LibC.signal signal, ->handler(Int32)
  end

  protected def handler(num)
    @@handlers.not_nil![num]?.try &.call(num)
  end
end
