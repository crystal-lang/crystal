{% skip_file unless flag?(:linux) && flag?(:aarch64) && !flag?(:interpreted) %}

module Syscall
  # :nodoc:
  # Based on https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/unistd.h
  enum Code : UInt64
    IO_SETUP                     =   0
    IO_DESTROY                   =   1
    IO_SUBMIT                    =   2
    IO_CANCEL                    =   3
    IO_GETEVENTS                 =   4
    SETXATTR                     =   5
    LSETXATTR                    =   6
    FSETXATTR                    =   7
    GETXATTR                     =   8
    LGETXATTR                    =   9
    FGETXATTR                    =  10
    LISTXATTR                    =  11
    LLISTXATTR                   =  12
    FLISTXATTR                   =  13
    REMOVEXATTR                  =  14
    LREMOVEXATTR                 =  15
    FREMOVEXATTR                 =  16
    GETCWD                       =  17
    LOOKUP_DCOOKIE               =  18
    EVENTFD2                     =  19
    EPOLL_CREATE1                =  20
    EPOLL_CTL                    =  21
    EPOLL_PWAIT                  =  22
    DUP                          =  23
    DUP3                         =  24
    FCNTL                        =  25
    INOTIFY_INIT1                =  26
    INOTIFY_ADD_WATCH            =  27
    INOTIFY_RM_WATCH             =  28
    IOCTL                        =  29
    IOPRIO_SET                   =  30
    IOPRIO_GET                   =  31
    FLOCK                        =  32
    MKNODAT                      =  33
    MKDIRAT                      =  34
    UNLINKAT                     =  35
    SYMLINKAT                    =  36
    LINKAT                       =  37
    RENAMEAT                     =  38
    UMOUNT2                      =  39
    MOUNT                        =  40
    PIVOT_ROOT                   =  41
    NFSSERVCTL                   =  42
    STATFS                       =  43
    FSTATFS                      =  44
    TRUNCATE                     =  45
    FTRUNCATE                    =  46
    FALLOCATE                    =  47
    FACCESSAT                    =  48
    CHDIR                        =  49
    FCHDIR                       =  50
    CHROOT                       =  51
    FCHMOD                       =  52
    FCHMODAT                     =  53
    FCHOWNAT                     =  54
    FCHOWN                       =  55
    OPENAT                       =  56
    CLOSE                        =  57
    VHANGUP                      =  58
    PIPE2                        =  59
    QUOTACTL                     =  60
    GETDENTS64                   =  61
    LSEEK                        =  62
    READ                         =  63
    WRITE                        =  64
    READV                        =  65
    WRITEV                       =  66
    PREAD64                      =  67
    PWRITE64                     =  68
    PREADV                       =  69
    PWRITEV                      =  70
    SENDFILE                     =  71
    PSELECT6                     =  72
    PPOLL                        =  73
    SIGNALFD4                    =  74
    VMSPLICE                     =  75
    SPLICE                       =  76
    TEE                          =  77
    READLINKAT                   =  78
    FSTATAT                      =  79
    FSTAT                        =  80
    SYNC                         =  81
    FSYNC                        =  82
    FDATASYNC                    =  83
    SYNC_FILE_RANGE2             =  84
    SYNC_FILE_RANGE              =  84
    TIMERFD_CREATE               =  85
    TIMERFD_SETTIME              =  86
    TIMERFD_GETTIME              =  87
    UTIMENSAT                    =  88
    ACCT                         =  89
    CAPGET                       =  90
    CAPSET                       =  91
    PERSONALITY                  =  92
    EXIT                         =  93
    EXIT_GROUP                   =  94
    WAITID                       =  95
    SET_TID_ADDRESS              =  96
    UNSHARE                      =  97
    FUTEX                        =  98
    SET_ROBUST_LIST              =  99
    GET_ROBUST_LIST              = 100
    NANOSLEEP                    = 101
    GETITIMER                    = 102
    SETITIMER                    = 103
    KEXEC_LOAD                   = 104
    INIT_MODULE                  = 105
    DELETE_MODULE                = 106
    TIMER_CREATE                 = 107
    TIMER_GETTIME                = 108
    TIMER_GETOVERRUN             = 109
    TIMER_SETTIME                = 110
    TIMER_DELETE                 = 111
    CLOCK_SETTIME                = 112
    CLOCK_GETTIME                = 113
    CLOCK_GETRES                 = 114
    CLOCK_NANOSLEEP              = 115
    SYSLOG                       = 116
    PTRACE                       = 117
    SCHED_SETPARAM               = 118
    SCHED_SETSCHEDULER           = 119
    SCHED_GETSCHEDULER           = 120
    SCHED_GETPARAM               = 121
    SCHED_SETAFFINITY            = 122
    SCHED_GETAFFINITY            = 123
    SCHED_YIELD                  = 124
    SCHED_GET_PRIORITY_MAX       = 125
    SCHED_GET_PRIORITY_MIN       = 126
    SCHED_RR_GET_INTERVAL        = 127
    RESTART_SYSCALL              = 128
    KILL                         = 129
    TKILL                        = 130
    TGKILL                       = 131
    SIGALTSTACK                  = 132
    RT_SIGSUSPEND                = 133
    RT_SIGACTION                 = 134
    RT_SIGPROCMASK               = 135
    RT_SIGPENDING                = 136
    RT_SIGTIMEDWAIT              = 137
    RT_SIGQUEUEINFO              = 138
    RT_SIGRETURN                 = 139
    SETPRIORITY                  = 140
    GETPRIORITY                  = 141
    REBOOT                       = 142
    SETREGID                     = 143
    SETGID                       = 144
    SETREUID                     = 145
    SETUID                       = 146
    SETRESUID                    = 147
    GETRESUID                    = 148
    SETRESGID                    = 149
    GETRESGID                    = 150
    SETFSUID                     = 151
    SETFSGID                     = 152
    TIMES                        = 153
    SETPGID                      = 154
    GETPGID                      = 155
    GETSID                       = 156
    SETSID                       = 157
    GETGROUPS                    = 158
    SETGROUPS                    = 159
    UNAME                        = 160
    SETHOSTNAME                  = 161
    SETDOMAINNAME                = 162
    GETRLIMIT                    = 163
    SETRLIMIT                    = 164
    GETRUSAGE                    = 165
    UMASK                        = 166
    PRCTL                        = 167
    GETCPU                       = 168
    GETTIMEOFDAY                 = 169
    SETTIMEOFDAY                 = 170
    ADJTIMEX                     = 171
    GETPID                       = 172
    GETPPID                      = 173
    GETUID                       = 174
    GETEUID                      = 175
    GETGID                       = 176
    GETEGID                      = 177
    GETTID                       = 178
    SYSINFO                      = 179
    MQ_OPEN                      = 180
    MQ_UNLINK                    = 181
    MQ_TIMEDSEND                 = 182
    MQ_TIMEDRECEIVE              = 183
    MQ_NOTIFY                    = 184
    MQ_GETSETATTR                = 185
    MSGGET                       = 186
    MSGCTL                       = 187
    MSGRCV                       = 188
    MSGSND                       = 189
    SEMGET                       = 190
    SEMCTL                       = 191
    SEMTIMEDOP                   = 192
    SEMOP                        = 193
    SHMGET                       = 194
    SHMCTL                       = 195
    SHMAT                        = 196
    SHMDT                        = 197
    SOCKET                       = 198
    SOCKETPAIR                   = 199
    BIND                         = 200
    LISTEN                       = 201
    ACCEPT                       = 202
    CONNECT                      = 203
    GETSOCKNAME                  = 204
    GETPEERNAME                  = 205
    SENDTO                       = 206
    RECVFROM                     = 207
    SETSOCKOPT                   = 208
    GETSOCKOPT                   = 209
    SHUTDOWN                     = 210
    SENDMSG                      = 211
    RECVMSG                      = 212
    READAHEAD                    = 213
    BRK                          = 214
    MUNMAP                       = 215
    MREMAP                       = 216
    ADD_KEY                      = 217
    REQUEST_KEY                  = 218
    KEYCTL                       = 219
    CLONE                        = 220
    EXECVE                       = 221
    MMAP                         = 222
    FADVISE64                    = 223
    SWAPON                       = 224
    SWAPOFF                      = 225
    MPROTECT                     = 226
    MSYNC                        = 227
    MLOCK                        = 228
    MUNLOCK                      = 229
    MLOCKALL                     = 230
    MUNLOCKALL                   = 231
    MINCORE                      = 232
    MADVISE                      = 233
    REMAP_FILE_PAGES             = 234
    MBIND                        = 235
    GET_MEMPOLICY                = 236
    SET_MEMPOLICY                = 237
    MIGRATE_PAGES                = 238
    MOVE_PAGES                   = 239
    RT_TGSIGQUEUEINFO            = 240
    PERF_EVENT_OPEN              = 241
    ACCEPT4                      = 242
    RECVMMSG                     = 243
    ARCH_SPECIFIC_SYSCALL        = 244
    WAIT4                        = 260
    PRLIMIT64                    = 261
    FANOTIFY_INIT                = 262
    FANOTIFY_MARK                = 263
    NAME_TO_HANDLE_AT            = 264
    OPEN_BY_HANDLE_AT            = 265
    CLOCK_ADJTIME                = 266
    SYNCFS                       = 267
    SETNS                        = 268
    SENDMMSG                     = 269
    PROCESS_VM_READV             = 270
    PROCESS_VM_WRITEV            = 271
    KCMP                         = 272
    FINIT_MODULE                 = 273
    SCHED_SETATTR                = 274
    SCHED_GETATTR                = 275
    RENAMEAT2                    = 276
    SECCOMP                      = 277
    GETRANDOM                    = 278
    MEMFD_CREATE                 = 279
    BPF                          = 280
    EXECVEAT                     = 281
    USERFAULTFD                  = 282
    MEMBARRIER                   = 283
    MLOCK2                       = 284
    COPY_FILE_RANGE              = 285
    PREADV2                      = 286
    PWRITEV2                     = 287
    PKEY_MPROTECT                = 288
    PKEY_ALLOC                   = 289
    PKEY_FREE                    = 290
    STATX                        = 291
    IO_PGETEVENTS                = 292
    RSEQ                         = 293
    KEXEC_FILE_LOAD              = 294
    CLOCK_GETTIME64              = 403
    CLOCK_SETTIME64              = 404
    CLOCK_ADJTIME64              = 405
    CLOCK_GETRES_TIME64          = 406
    CLOCK_NANOSLEEP_TIME64       = 407
    TIMER_GETTIME64              = 408
    TIMER_SETTIME64              = 409
    TIMERFD_GETTIME64            = 410
    TIMERFD_SETTIME64            = 411
    UTIMENSAT_TIME64             = 412
    PSELECT6_TIME64              = 413
    PPOLL_TIME64                 = 414
    IO_PGETEVENTS_TIME64         = 416
    RECVMMSG_TIME64              = 417
    MQ_TIMEDSEND_TIME64          = 418
    MQ_TIMEDRECEIVE_TIME64       = 419
    SEMTIMEDOP_TIME64            = 420
    RT_SIGTIMEDWAIT_TIME64       = 421
    FUTEX_TIME64                 = 422
    SCHED_RR_GET_INTERVAL_TIME64 = 423
    PIDFD_SEND_SIGNAL            = 424
    IO_URING_SETUP               = 425
    IO_URING_ENTER               = 426
    IO_URING_REGISTER            = 427
    OPEN_TREE                    = 428
    MOVE_MOUNT                   = 429
    FSOPEN                       = 430
    FSCONFIG                     = 431
    FSMOUNT                      = 432
    FSPICK                       = 433
    PIDFD_OPEN                   = 434
    CLONE3                       = 435
    CLOSE_RANGE                  = 436
    OPENAT2                      = 437
    PIDFD_GETFD                  = 438
    FACCESSAT2                   = 439
    PROCESS_MADVISE              = 440
    EPOLL_PWAIT2                 = 441
    MOUNT_SETATTR                = 442
    QUOTACTL_PATH                = 443
    LANDLOCK_CREATE_RULESET      = 444
    LANDLOCK_ADD_RULE            = 445
    LANDLOCK_RESTRICT_SELF       = 446
    MEMFD_SECRET                 = 447
    PROCESS_MRELEASE             = 448
    FUTEX_WAITV                  = 449
  end

  macro def_syscall(name, return_type, *args)
    @[::AlwaysInline]
    def self.{{ name.id }}({{ args.splat }}) : {{ return_type }}
      ret = uninitialized {{ return_type }}

      {% if args.size == 0 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }})
                     : "memory"
                     : "volatile")
      {% elsif args.size == 1 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{x0}"({{ args[0].var.id }})
                     : "memory"
                     : "volatile")
      {% elsif args.size == 2 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{x0}"({{ args[0].var.id }}), "{x1}"({{ args[1].var.id }})
                     : "memory"
                     : "volatile")
      {% elsif args.size == 3 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{x0}"({{ args[0].var.id }}), "{x1}"({{ args[1].var.id }}),
                       "{x2}"({{ args[2].var.id }})
                     : "memory"
                     : "volatile")
      {% elsif args.size == 4 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{x0}"({{ args[0].var.id }}), "{x1}"({{ args[1].var.id }}),
                       "{x2}"({{ args[2].var.id }}), "{x3}"({{ args[3].var.id }})
                     : "memory"
                     : "volatile")
      {% elsif args.size == 5 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{x0}"({{ args[0].var.id }}), "{x1}"({{ args[1].var.id }}),
                       "{x2}"({{ args[2].var.id }}), "{x3}"({{ args[3].var.id }}), "{x4}"({{ args[4].var.id }})
                     : "memory"
                     : "volatile")
      {% elsif args.size == 6 %}
        asm("svc #0" : "={x0}"(ret)
                     : "{w8}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{x0}"({{ args[0].var.id }}), "{x1}"({{ args[1].var.id }}),
                       "{x2}"({{ args[2].var.id }}), "{x3}"({{ args[3].var.id }}), "{x4}"({{ args[4].var.id }}), "{x5}"({{ args[5].var.id }})
                     : "memory"
                     : "volatile")
      {% else %}
        {% raise "Not supported number of arguments for syscall" %}
      {% end %}

      ret
    end
  end
end
