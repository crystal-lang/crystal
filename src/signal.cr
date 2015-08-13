lib LibC
  fun signal(sig : Int32, handler : Int32 ->)
end


ifdef darwin
  enum Signal
    NONE   =  0
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
    VTALRM = 26
    PROF   = 27
    WINCH  = 28
    INFO   = 29
    USR1   = 30
    USR2   = 31
  end
else
  enum Signal
    NONE   = 0
    HUP    = 1
    INT    = 2
    QUIT   = 3
    ILL    = 4
    TRAP   = 5
    ABRT   = 6
    IOT    = 6
    BUS    = 7
    FPE    = 8
    KILL   = 9
    USR1   = 10
    SEGV   = 11
    USR2   = 12
    PIPE   = 13
    ALRM   = 14
    TERM   = 15
    STKFLT = 16
    CLD    = 17
    CHLD   = 17
    CONT   = 18
    STOP   = 19
    TSTP   = 20
    TTIN   = 21
    TTOU   = 22
    URG    = 23
    XCPU   = 24
    XFSZ   = 25
    VTALRM = 26
    PROF   = 27
    WINCH  = 28
    POLL   = 29
    IO     = 29
    PWR    = 30
    SYS    = 31
    UNUSED = 31
  end
end

enum Signal
  def trap(block : Int32 ->)
    trap &block
  end

  def trap(&block : Int32 ->)
    if block.closure?
      handlers = @@handlers ||= {} of Int32 => Int32 ->
      handlers[value] = block
      LibC.signal value, ->(num) do
        @@handlers.not_nil![num]?.try &.call(num)
      end
    else
      LibC.signal value, block
    end
  end

  def reset
    trap Proc(Int32, Void).new(Pointer(Void).new(0_u64), Pointer(Void).null)
  end

  def ignore
    trap Proc(Int32, Void).new(Pointer(Void).new(1_u64), Pointer(Void).null)
  end
end
