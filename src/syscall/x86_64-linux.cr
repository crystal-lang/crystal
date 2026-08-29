{% skip_file unless flag?(:linux) && flag?(:x86_64) && !flag?(:interpreted) %}

module Syscall
  # :nodoc:
  # Based on https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl
  enum Code : UInt64
    READ                    =   0
    WRITE                   =   1
    OPEN                    =   2
    CLOSE                   =   3
    STAT                    =   4
    FSTAT                   =   5
    LSTAT                   =   6
    POLL                    =   7
    LSEEK                   =   8
    MMAP                    =   9
    MPROTECT                =  10
    MUNMAP                  =  11
    BRK                     =  12
    RT_SIGACTION            =  13
    RT_SIGPROCMASK          =  14
    RT_SIGRETURN            =  15
    IOCTL                   =  16
    PREAD64                 =  17
    PWRITE64                =  18
    READV                   =  19
    WRITEV                  =  20
    ACCESS                  =  21
    PIPE                    =  22
    SELECT                  =  23
    SCHED_YIELD             =  24
    MREMAP                  =  25
    MSYNC                   =  26
    MINCORE                 =  27
    MADVISE                 =  28
    SHMGET                  =  29
    SHMAT                   =  30
    SHMCTL                  =  31
    DUP                     =  32
    DUP2                    =  33
    PAUSE                   =  34
    NANOSLEEP               =  35
    GETITIMER               =  36
    ALARM                   =  37
    SETITIMER               =  38
    GETPID                  =  39
    SENDFILE                =  40
    SOCKET                  =  41
    CONNECT                 =  42
    ACCEPT                  =  43
    SENDTO                  =  44
    RECVFROM                =  45
    SENDMSG                 =  46
    RECVMSG                 =  47
    SHUTDOWN                =  48
    BIND                    =  49
    LISTEN                  =  50
    GETSOCKNAME             =  51
    GETPEERNAME             =  52
    SOCKETPAIR              =  53
    SETSOCKOPT              =  54
    GETSOCKOPT              =  55
    CLONE                   =  56
    FORK                    =  57
    VFORK                   =  58
    EXECVE                  =  59
    EXIT                    =  60
    WAIT4                   =  61
    KILL                    =  62
    UNAME                   =  63
    SEMGET                  =  64
    SEMOP                   =  65
    SEMCTL                  =  66
    SHMDT                   =  67
    MSGGET                  =  68
    MSGSND                  =  69
    MSGRCV                  =  70
    MSGCTL                  =  71
    FCNTL                   =  72
    FLOCK                   =  73
    FSYNC                   =  74
    FDATASYNC               =  75
    TRUNCATE                =  76
    FTRUNCATE               =  77
    GETDENTS                =  78
    GETCWD                  =  79
    CHDIR                   =  80
    FCHDIR                  =  81
    RENAME                  =  82
    MKDIR                   =  83
    RMDIR                   =  84
    CREAT                   =  85
    LINK                    =  86
    UNLINK                  =  87
    SYMLINK                 =  88
    READLINK                =  89
    CHMOD                   =  90
    FCHMOD                  =  91
    CHOWN                   =  92
    FCHOWN                  =  93
    LCHOWN                  =  94
    UMASK                   =  95
    GETTIMEOFDAY            =  96
    GETRLIMIT               =  97
    GETRUSAGE               =  98
    SYSINFO                 =  99
    TIMES                   = 100
    PTRACE                  = 101
    GETUID                  = 102
    SYSLOG                  = 103
    GETGID                  = 104
    SETUID                  = 105
    SETGID                  = 106
    GETEUID                 = 107
    GETEGID                 = 108
    SETPGID                 = 109
    GETPPID                 = 110
    GETPGRP                 = 111
    SETSID                  = 112
    SETREUID                = 113
    SETREGID                = 114
    GETGROUPS               = 115
    SETGROUPS               = 116
    SETRESUID               = 117
    GETRESUID               = 118
    SETRESGID               = 119
    GETRESGID               = 120
    GETPGID                 = 121
    SETFSUID                = 122
    SETFSGID                = 123
    GETSID                  = 124
    CAPGET                  = 125
    CAPSET                  = 126
    RT_SIGPENDING           = 127
    RT_SIGTIMEDWAIT         = 128
    RT_SIGQUEUEINFO         = 129
    RT_SIGSUSPEND           = 130
    SIGALTSTACK             = 131
    UTIME                   = 132
    MKNOD                   = 133
    USELIB                  = 134
    PERSONALITY             = 135
    USTAT                   = 136
    STATFS                  = 137
    FSTATFS                 = 138
    SYSFS                   = 139
    GETPRIORITY             = 140
    SETPRIORITY             = 141
    SCHED_SETPARAM          = 142
    SCHED_GETPARAM          = 143
    SCHED_SETSCHEDULER      = 144
    SCHED_GETSCHEDULER      = 145
    SCHED_GET_PRIORITY_MAX  = 146
    SCHED_GET_PRIORITY_MIN  = 147
    SCHED_RR_GET_INTERVAL   = 148
    MLOCK                   = 149
    MUNLOCK                 = 150
    MLOCKALL                = 151
    MUNLOCKALL              = 152
    VHANGUP                 = 153
    MODIFY_LDT              = 154
    PIVOT_ROOT              = 155
    SYSCTL                  = 156
    PRCTL                   = 157
    ARCH_PRCTL              = 158
    ADJTIMEX                = 159
    SETRLIMIT               = 160
    CHROOT                  = 161
    SYNC                    = 162
    ACCT                    = 163
    SETTIMEOFDAY            = 164
    MOUNT                   = 165
    UMOUNT2                 = 166
    SWAPON                  = 167
    SWAPOFF                 = 168
    REBOOT                  = 169
    SETHOSTNAME             = 170
    SETDOMAINNAME           = 171
    IOPL                    = 172
    IOPERM                  = 173
    CREATE_MODULE           = 174
    INIT_MODULE             = 175
    DELETE_MODULE           = 176
    GET_KERNEL_SYMS         = 177
    QUERY_MODULE            = 178
    QUOTACTL                = 179
    NFSSERVCTL              = 180
    GETPMSG                 = 181
    PUTPMSG                 = 182
    AFS_SYSCALL             = 183
    TUXCALL                 = 184
    SECURITY                = 185
    GETTID                  = 186
    READAHEAD               = 187
    SETXATTR                = 188
    LSETXATTR               = 189
    FSETXATTR               = 190
    GETXATTR                = 191
    LGETXATTR               = 192
    FGETXATTR               = 193
    LISTXATTR               = 194
    LLISTXATTR              = 195
    FLISTXATTR              = 196
    REMOVEXATTR             = 197
    LREMOVEXATTR            = 198
    FREMOVEXATTR            = 199
    TKILL                   = 200
    TIME                    = 201
    FUTEX                   = 202
    SCHED_SETAFFINITY       = 203
    SCHED_GETAFFINITY       = 204
    SET_THREAD_AREA         = 205
    IO_SETUP                = 206
    IO_DESTROY              = 207
    IO_GETEVENTS            = 208
    IO_SUBMIT               = 209
    IO_CANCEL               = 210
    GET_THREAD_AREA         = 211
    LOOKUP_DCOOKIE          = 212
    EPOLL_CREATE            = 213
    EPOLL_CTL_OLD           = 214
    EPOLL_WAIT_OLD          = 215
    REMAP_FILE_PAGES        = 216
    GETDENTS64              = 217
    SET_TID_ADDRESS         = 218
    RESTART_SYSCALL         = 219
    SEMTIMEDOP              = 220
    FADVISE64               = 221
    TIMER_CREATE            = 222
    TIMER_SETTIME           = 223
    TIMER_GETTIME           = 224
    TIMER_GETOVERRUN        = 225
    TIMER_DELETE            = 226
    CLOCK_SETTIME           = 227
    CLOCK_GETTIME           = 228
    CLOCK_GETRES            = 229
    CLOCK_NANOSLEEP         = 230
    EXIT_GROUP              = 231
    EPOLL_WAIT              = 232
    EPOLL_CTL               = 233
    TGKILL                  = 234
    UTIMES                  = 235
    VSERVER                 = 236
    MBIND                   = 237
    SET_MEMPOLICY           = 238
    GET_MEMPOLICY           = 239
    MQ_OPEN                 = 240
    MQ_UNLINK               = 241
    MQ_TIMEDSEND            = 242
    MQ_TIMEDRECEIVE         = 243
    MQ_NOTIFY               = 244
    MQ_GETSETATTR           = 245
    KEXEC_LOAD              = 246
    WAITID                  = 247
    ADD_KEY                 = 248
    REQUEST_KEY             = 249
    KEYCTL                  = 250
    IOPRIO_SET              = 251
    IOPRIO_GET              = 252
    INOTIFY_INIT            = 253
    INOTIFY_ADD_WATCH       = 254
    INOTIFY_RM_WATCH        = 255
    MIGRATE_PAGES           = 256
    OPENAT                  = 257
    MKDIRAT                 = 258
    MKNODAT                 = 259
    FCHOWNAT                = 260
    FUTIMESAT               = 261
    NEWFSTATAT              = 262
    UNLINKAT                = 263
    RENAMEAT                = 264
    LINKAT                  = 265
    SYMLINKAT               = 266
    READLINKAT              = 267
    FCHMODAT                = 268
    FACCESSAT               = 269
    PSELECT6                = 270
    PPOLL                   = 271
    UNSHARE                 = 272
    SET_ROBUST_LIST         = 273
    GET_ROBUST_LIST         = 274
    SPLICE                  = 275
    TEE                     = 276
    SYNC_FILE_RANGE         = 277
    VMSPLICE                = 278
    MOVE_PAGES              = 279
    UTIMENSAT               = 280
    EPOLL_PWAIT             = 281
    SIGNALFD                = 282
    TIMERFD_CREATE          = 283
    EVENTFD                 = 284
    FALLOCATE               = 285
    TIMERFD_SETTIME         = 286
    TIMERFD_GETTIME         = 287
    ACCEPT4                 = 288
    SIGNALFD4               = 289
    EVENTFD2                = 290
    EPOLL_CREATE1           = 291
    DUP3                    = 292
    PIPE2                   = 293
    INOTIFY_INIT1           = 294
    PREADV                  = 295
    PWRITEV                 = 296
    RT_TGSIGQUEUEINFO       = 297
    PERF_EVENT_OPEN         = 298
    RECVMMSG                = 299
    FANOTIFY_INIT           = 300
    FANOTIFY_MARK           = 301
    PRLIMIT64               = 302
    NAME_TO_HANDLE_AT       = 303
    OPEN_BY_HANDLE_AT       = 304
    CLOCK_ADJTIME           = 305
    SYNCFS                  = 306
    SENDMMSG                = 307
    SETNS                   = 308
    GETCPU                  = 309
    PROCESS_VM_READV        = 310
    PROCESS_VM_WRITEV       = 311
    KCMP                    = 312
    FINIT_MODULE            = 313
    SCHED_SETATTR           = 314
    SCHED_GETATTR           = 315
    RENAMEAT2               = 316
    SECCOMP                 = 317
    GETRANDOM               = 318
    MEMFD_CREATE            = 319
    KEXEC_FILE_LOAD         = 320
    BPF                     = 321
    EXECVEAT                = 322
    USERFAULTFD             = 323
    MEMBARRIER              = 324
    MLOCK2                  = 325
    COPY_FILE_RANGE         = 326
    PREADV2                 = 327
    PWRITEV2                = 328
    PKEY_MPROTECT           = 329
    PKEY_ALLOC              = 330
    PKEY_FREE               = 331
    STATX                   = 332
    IO_PGETEVENTS           = 333
    RSEQ                    = 334
    PIDFD_SEND_SIGNAL       = 424
    IO_URING_SETUP          = 425
    IO_URING_ENTER          = 426
    IO_URING_REGISTER       = 427
    OPEN_TREE               = 428
    MOVE_MOUNT              = 429
    FSOPEN                  = 430
    FSCONFIG                = 431
    FSMOUNT                 = 432
    FSPICK                  = 433
    PIDFD_OPEN              = 434
    CLONE3                  = 435
    CLOSE_RANGE             = 436
    OPENAT2                 = 437
    PIDFD_GETFD             = 438
    FACCESSAT2              = 439
    PROCESS_MADVISE         = 440
    EPOLL_PWAIT2            = 441
    MOUNT_SETATTR           = 442
    QUOTACTL_PATH           = 443
    LANDLOCK_CREATE_RULESET = 444
    LANDLOCK_ADD_RULE       = 445
    LANDLOCK_RESTRICT_SELF  = 446
    MEMFD_SECRET            = 447
    PROCESS_MRELEASE        = 448
    FUTEX_WAITV             = 449
  end

  macro def_syscall(name, return_type, *args)
    @[::AlwaysInline]
    def self.{{ name.id }}({{ args.splat }}) : {{ return_type }}
      ret = uninitialized {{ return_type }}

      {% if args.size == 0 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% elsif args.size == 1 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{rdi}"({{ args[0].var.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% elsif args.size == 2 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{rdi}"({{ args[0].var.id }}), "{rsi}"({{ args[1].var.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% elsif args.size == 3 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{rdi}"({{ args[0].var.id }}), "{rsi}"({{ args[1].var.id }}),
                        "{rdx}"({{ args[2].var.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% elsif args.size == 4 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{rdi}"({{ args[0].var.id }}), "{rsi}"({{ args[1].var.id }}),
                        "{rdx}"({{ args[2].var.id }}), "{r10}"({{ args[3].var.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% elsif args.size == 5 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{rdi}"({{ args[0].var.id }}), "{rsi}"({{ args[1].var.id }}),
                        "{rdx}"({{ args[2].var.id }}), "{r10}"({{ args[3].var.id }}), "{r8}"({{ args[4].var.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% elsif args.size == 6 %}
        asm("syscall" : "={rax}"(ret)
                      : "{rax}"(::Syscall::Code::{{ name.stringify.upcase.id }}), "{rdi}"({{ args[0].var.id }}), "{rsi}"({{ args[1].var.id }}),
                        "{rdx}"({{ args[2].var.id }}), "{r10}"({{ args[3].var.id }}), "{r8}"({{ args[4].var.id }}), "{r9}"({{ args[5].var.id }})
                      : "rcx", "r11", "memory"
                      : "volatile")
      {% else %}
        {% raise "Not supported number of arguments for syscall" %}
      {% end %}

      ret
    end
  end
end
