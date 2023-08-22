lib LibC
  CTL_HW  = 6
  HW_NCPU = 3

  CTL_KERN           =  1
  KERN_PROC          = 14
  KERN_PROC_ARGS     = 48
  KERN_PROC_PATHNAME =  5

  PATH_MAX = 1024

  fun sysctl(name : Int*, namelen : UInt, oldp : Void*, oldlenp : SizeT*, newp : Void*, newlen : SizeT) : Int
end
