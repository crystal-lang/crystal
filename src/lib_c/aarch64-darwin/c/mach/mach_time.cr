lib LibC
  struct MachTimebaseInfo
    numer : UInt32
    denom : UInt32
  end

  fun mach_timebase_info(info : MachTimebaseInfo*) : LibC::Int
  fun mach_absolute_time : UInt64
end
