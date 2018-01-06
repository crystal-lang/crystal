lib LibC

 # Top-level identifiers
  CTL_UNSPEC        =  0  # unused
  CTL_KERN          =  1  # "high kernel": proc, limits
  CTL_VM            =  2  # virtual memory
  CTL_FS            =  3  # file system, mount type is next
  CTL_NET           =  4  # network, see socket.h
  CTL_DEBUG         =  5  # debugging parameters
  CTL_HW            =  6  # generic cpu/io
  CTL_MACHDEP       =  7  # machine dependent

  CTL_DDB           =  9  # DDB user interface, see db_var.h
  CTL_VFS           = 10  # VFS sysctl's
  CTL_MAXID         = 11  # number of valid top-level ids

  # CTL_HW identifiers
  HW_MACHINE        =  1  # string: machine class
  HW_MODEL          =  2  # string: specific machine model
  HW_NCPU           =  3  # int: number of cpus being used
  HW_BYTEORDER      =  4  # int: machine byte order
  HW_PHYSMEM        =  5  # int: total memory
  HW_USERMEM        =  6  # int: non-kernel memory
  HW_PAGESIZE       =  7  # int: software page size
  HW_DISKNAMES      =  8  # strings: disk drive names
  HW_DISKSTATS      =  9  # struct: diskstats[]
  HW_DISKCOUNT      = 10  # int: number of disks
  HW_SENSORS        = 11  # node: hardware monitors
  HW_CPUSPEED       = 12  # get CPU frequency
  HW_SETPERF        = 13  # set CPU performance %
  HW_VENDOR         = 14  # string: vendor name
  HW_PRODUCT        = 15  # string: product name
  HW_VERSION        = 16  # string: hardware version
  HW_SERIALNO       = 17  # string: hardware serial number
  HW_UUID           = 18  # string: universal unique id
  HW_PHYSMEM64      = 19  # quad: total memory
  HW_USERMEM64      = 20  # quad: non-kernel memory
  HW_NCPUFOUND      = 21  # int: number of cpus foun
  HW_ALLOWPOWERDOWN = 22  # allow power button shutdown
  HW_PERFPOLICY     = 23  # set performance policy
  HW_MAXID          = 24  # number of valid hw ids

  fun sysctl(name : Int*, namelen : UInt, oldp : Void*, oldlenp : SizeT*, newp : Void*, newlen : SizeT) : Int
end
