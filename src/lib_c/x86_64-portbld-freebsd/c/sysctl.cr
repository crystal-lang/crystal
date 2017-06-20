lib LibC
  CTL_HW             =    6
  CTL_KERN           =    1
  HW_NCPU            =    3
  KERN_PROC          =   14
  KERN_PROC_PATHNAME =   12
  PATH_MAX           = 1024

  fun sysctl(name : Int*, namelen : UInt, oldp : Void*, oldlenp : SizeT*, newp : Void*, newlen : SizeT) : Int
end
