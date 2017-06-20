lib LibC
  CTL_HW  = 6
  HW_NCPU = 3

  fun sysctl(name : Int*, namelen : UInt, oldp : Void*, oldlenp : SizeT*, newp : Void*, newlen : SizeT) : Int
end
