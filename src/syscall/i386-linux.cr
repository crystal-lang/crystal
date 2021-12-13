{% skip_file unless flag?(:linux) && flag?(:i386) && !flag?(:interpreted) %}

module Syscall
  # :nodoc:
  # Based on https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_32.tbl
  enum Code : UInt32
    RESTART_SYSCALL              =   0
    EXIT                         =   1
    FORK                         =   2
    READ                         =   3
    WRITE                        =   4
    OPEN                         =   5
    CLOSE                        =   6
    WAITPID                      =   7
    CREAT                        =   8
    LINK                         =   9
    UNLINK                       =  10
    EXECVE                       =  11
    CHDIR                        =  12
    TIME                         =  13
    MKNOD                        =  14
    CHMOD                        =  15
    LCHOWN                       =  16
    BREAK                        =  17
    OLDSTAT                      =  18
    LSEEK                        =  19
    GETPID                       =  20
    MOUNT                        =  21
    UMOUNT                       =  22
    SETUID                       =  23
    GETUID                       =  24
    STIME                        =  25
    PTRACE                       =  26
    ALARM                        =  27
    OLDFSTAT                     =  28
    PAUSE                        =  29
    UTIME                        =  30
    STTY                         =  31
    GTTY                         =  32
    ACCESS                       =  33
    NICE                         =  34
    FTIME                        =  35
    SYNC                         =  36
    KILL                         =  37
    RENAME                       =  38
    MKDIR                        =  39
    RMDIR                        =  40
    DUP                          =  41
    PIPE                         =  42
    TIMES                        =  43
    PROF                         =  44
    BRK                          =  45
    SETGID                       =  46
    GETGID                       =  47
    SIGNAL                       =  48
    GETEUID                      =  49
    GETEGID                      =  50
    ACCT                         =  51
    UMOUNT2                      =  52
    LOCK                         =  53
    IOCTL                        =  54
    FCNTL                        =  55
    MPX                          =  56
    SETPGID                      =  57
    ULIMIT                       =  58
    OLDOLDUNAME                  =  59
    UMASK                        =  60
    CHROOT                       =  61
    USTAT                        =  62
    DUP2                         =  63
    GETPPID                      =  64
    GETPGRP                      =  65
    SETSID                       =  66
    SIGACTION                    =  67
    SGETMASK                     =  68
    SSETMASK                     =  69
    SETREUID                     =  70
    SETREGID                     =  71
    SIGSUSPEND                   =  72
    SIGPENDING                   =  73
    SETHOSTNAME                  =  74
    SETRLIMIT                    =  75
    GETRLIMIT                    =  76
    GETRUSAGE                    =  77
    GETTIMEOFDAY                 =  78
    SETTIMEOFDAY                 =  79
    GETGROUPS                    =  80
    SETGROUPS                    =  81
    SELECT                       =  82
    SYMLINK                      =  83
    OLDLSTAT                     =  84
    READLINK                     =  85
    USELIB                       =  86
    SWAPON                       =  87
    REBOOT                       =  88
    READDIR                      =  89
    MMAP                         =  90
    MUNMAP                       =  91
    TRUNCATE                     =  92
    FTRUNCATE                    =  93
    FCHMOD                       =  94
    FCHOWN                       =  95
    GETPRIORITY                  =  96
    SETPRIORITY                  =  97
    PROFIL                       =  98
    STATFS                       =  99
    FSTATFS                      = 100
    IOPERM                       = 101
    SOCKETCALL                   = 102
    SYSLOG                       = 103
    SETITIMER                    = 104
    GETITIMER                    = 105
    STAT                         = 106
    LSTAT                        = 107
    FSTAT                        = 108
    OLDUNAME                     = 109
    IOPL                         = 110
    VHANGUP                      = 111
    IDLE                         = 112
    VM86OLD                      = 113
    WAIT4                        = 114
    SWAPOFF                      = 115
    SYSINFO                      = 116
    IPC                          = 117
    FSYNC                        = 118
    SIGRETURN                    = 119
    CLONE                        = 120
    SETDOMAINNAME                = 121
    UNAME                        = 122
    MODIFY_LDT                   = 123
    ADJTIMEX                     = 124
    MPROTECT                     = 125
    SIGPROCMASK                  = 126
    CREATE_MODULE                = 127
    INIT_MODULE                  = 128
    DELETE_MODULE                = 129
    GET_KERNEL_SYMS              = 130
    QUOTACTL                     = 131
    GETPGID                      = 132
    FCHDIR                       = 133
    BDFLUSH                      = 134
    SYSFS                        = 135
    PERSONALITY                  = 136
    AFS_SYSCALL                  = 137
    SETFSUID                     = 138
    SETFSGID                     = 139
    LLSEEK                       = 140
    GETDENTS                     = 141
    NEWSELECT                    = 142
    FLOCK                        = 143
    MSYNC                        = 144
    READV                        = 145
    WRITEV                       = 146
    GETSID                       = 147
    FDATASYNC                    = 148
    MLOCK                        = 150
    MUNLOCK                      = 151
    MLOCKALL                     = 152
    MUNLOCKALL                   = 153
    SCHED_SETPARAM               = 154
    SCHED_GETPARAM               = 155
    SCHED_SETSCHEDULER           = 156
    SCHED_GETSCHEDULER           = 157
    SCHED_YIELD                  = 158
    SCHED_GET_PRIORITY_MAX       = 159
    SCHED_GET_PRIORITY_MIN       = 160
    SCHED_RR_GET_INTERVAL        = 161
    NANOSLEEP                    = 162
    MREMAP                       = 163
    SETRESUID                    = 164
    GETRESUID                    = 165
    VM86                         = 166
    QUERY_MODULE                 = 167
    POLL                         = 168
    NFSSERVCTL                   = 169
    SETRESGID                    = 170
    GETRESGID                    = 171
    PRCTL                        = 172
    RT_SIGRETURN                 = 173
    RT_SIGACTION                 = 174
    RT_SIGPROCMASK               = 175
    RT_SIGPENDING                = 176
    RT_SIGTIMEDWAIT              = 177
    RT_SIGQUEUEINFO              = 178
    RT_SIGSUSPEND                = 179
    PREAD64                      = 180
    PWRITE64                     = 181
    CHOWN                        = 182
    GETCWD                       = 183
    CAPGET                       = 184
    CAPSET                       = 185
    SIGALTSTACK                  = 186
    SENDFILE                     = 187
    GETPMSG                      = 188
    PUTPMSG                      = 189
    VFORK                        = 190
    UGETRLIMIT                   = 191
    MMAP2                        = 192
    TRUNCATE64                   = 193
    FTRUNCATE64                  = 194
    STAT64                       = 195
    LSTAT64                      = 196
    FSTAT64                      = 197
    LCHOWN32                     = 198
    GETUID32                     = 199
    GETGID32                     = 200
    GETEUID32                    = 201
    GETEGID32                    = 202
    SETREUID32                   = 203
    SETREGID32                   = 204
    GETGROUPS32                  = 205
    SETGROUPS32                  = 206
    FCHOWN32                     = 207
    SETRESUID32                  = 208
    GETRESUID32                  = 209
    SETRESGID32                  = 210
    GETRESGID32                  = 211
    CHOWN32                      = 212
    SETUID32                     = 213
    SETGID32                     = 214
    SETFSUID32                   = 215
    SETFSGID32                   = 216
    PIVOT_ROOT                   = 217
    MINCORE                      = 218
    MADVISE                      = 219
    GETDENTS64                   = 220
    FCNTL64                      = 221
    GETTID                       = 224
    READAHEAD                    = 225
    SETXATTR                     = 226
    LSETXATTR                    = 227
    FSETXATTR                    = 228
    GETXATTR                     = 229
    LGETXATTR                    = 230
    FGETXATTR                    = 231
    LISTXATTR                    = 232
    LLISTXATTR                   = 233
    FLISTXATTR                   = 234
    REMOVEXATTR                  = 235
    LREMOVEXATTR                 = 236
    FREMOVEXATTR                 = 237
    TKILL                        = 238
    SENDFILE64                   = 239
    FUTEX                        = 240
    SCHED_SETAFFINITY            = 241
    SCHED_GETAFFINITY            = 242
    SET_THREAD_AREA              = 243
    GET_THREAD_AREA              = 244
    IO_SETUP                     = 245
    IO_DESTROY                   = 246
    IO_GETEVENTS                 = 247
    IO_SUBMIT                    = 248
    IO_CANCEL                    = 249
    FADVISE64                    = 250
    EXIT_GROUP                   = 252
    LOOKUP_DCOOKIE               = 253
    EPOLL_CREATE                 = 254
    EPOLL_CTL                    = 255
    EPOLL_WAIT                   = 256
    REMAP_FILE_PAGES             = 257
    SET_TID_ADDRESS              = 258
    TIMER_CREATE                 = 259
    TIMER_SETTIME                = 260
    TIMER_GETTIME                = 261
    TIMER_GETOVERRUN             = 262
    TIMER_DELETE                 = 263
    CLOCK_SETTIME                = 264
    CLOCK_GETTIME                = 265
    CLOCK_GETRES                 = 266
    CLOCK_NANOSLEEP              = 267
    STATFS64                     = 268
    FSTATFS64                    = 269
    TGKILL                       = 270
    UTIMES                       = 271
    FADVISE64_64                 = 272
    VSERVER                      = 273
    MBIND                        = 274
    GET_MEMPOLICY                = 275
    SET_MEMPOLICY                = 276
    MQ_OPEN                      = 277
    MQ_UNLINK                    = 278
    MQ_TIMEDSEND                 = 279
    MQ_TIMEDRECEIVE              = 280
    MQ_NOTIFY                    = 281
    MQ_GETSETATTR                = 282
    KEXEC_LOAD                   = 283
    WAITID                       = 284
    ADD_KEY                      = 286
    REQUEST_KEY                  = 287
    KEYCTL                       = 288
    IOPRIO_SET                   = 289
    IOPRIO_GET                   = 290
    INOTIFY_INIT                 = 291
    INOTIFY_ADD_WATCH            = 292
    INOTIFY_RM_WATCH             = 293
    MIGRATE_PAGES                = 294
    OPENAT                       = 295
    MKDIRAT                      = 296
    MKNODAT                      = 297
    FCHOWNAT                     = 298
    FUTIMESAT                    = 299
    FSTATAT64                    = 300
    UNLINKAT                     = 301
    RENAMEAT                     = 302
    LINKAT                       = 303
    SYMLINKAT                    = 304
    READLINKAT                   = 305
    FCHMODAT                     = 306
    FACCESSAT                    = 307
    PSELECT6                     = 308
    PPOLL                        = 309
    UNSHARE                      = 310
    SET_ROBUST_LIST              = 311
    GET_ROBUST_LIST              = 312
    SPLICE                       = 313
    SYNC_FILE_RANGE              = 314
    TEE                          = 315
    VMSPLICE                     = 316
    MOVE_PAGES                   = 317
    GETCPU                       = 318
    EPOLL_PWAIT                  = 319
    UTIMENSAT                    = 320
    SIGNALFD                     = 321
    TIMERFD_CREATE               = 322
    EVENTFD                      = 323
    FALLOCATE                    = 324
    TIMERFD_SETTIME              = 325
    TIMERFD_GETTIME              = 326
    SIGNALFD4                    = 327
    EVENTFD2                     = 328
    EPOLL_CREATE1                = 329
    DUP3                         = 330
    PIPE2                        = 331
    INOTIFY_INIT1                = 332
    PREADV                       = 333
    PWRITEV                      = 334
    RT_TGSIGQUEUEINFO            = 335
    PERF_EVENT_OPEN              = 336
    RECVMMSG                     = 337
    FANOTIFY_INIT                = 338
    FANOTIFY_MARK                = 339
    PRLIMIT64                    = 340
    NAME_TO_HANDLE_AT            = 341
    OPEN_BY_HANDLE_AT            = 342
    CLOCK_ADJTIME                = 343
    SYNCFS                       = 344
    SENDMMSG                     = 345
    SETNS                        = 346
    PROCESS_VM_READV             = 347
    PROCESS_VM_WRITEV            = 348
    KCMP                         = 349
    FINIT_MODULE                 = 350
    SCHED_SETATTR                = 351
    SCHED_GETATTR                = 352
    RENAMEAT2                    = 353
    SECCOMP                      = 354
    GETRANDOM                    = 355
    MEMFD_CREATE                 = 356
    BPF                          = 357
    EXECVEAT                     = 358
    SOCKET                       = 359
    SOCKETPAIR                   = 360
    BIND                         = 361
    CONNECT                      = 362
    LISTEN                       = 363
    ACCEPT4                      = 364
    GETSOCKOPT                   = 365
    SETSOCKOPT                   = 366
    GETSOCKNAME                  = 367
    GETPEERNAME                  = 368
    SENDTO                       = 369
    SENDMSG                      = 370
    RECVFROM                     = 371
    RECVMSG                      = 372
    SHUTDOWN                     = 373
    USERFAULTFD                  = 374
    MEMBARRIER                   = 375
    MLOCK2                       = 376
    COPY_FILE_RANGE              = 377
    PREADV2                      = 378
    PWRITEV2                     = 379
    PKEY_MPROTECT                = 380
    PKEY_ALLOC                   = 381
    PKEY_FREE                    = 382
    STATX                        = 383
    ARCH_PRCTL                   = 384
    IO_PGETEVENTS                = 385
    RSEQ                         = 386
    SEMGET                       = 393
    SEMCTL                       = 394
    SHMGET                       = 395
    SHMCTL                       = 396
    SHMAT                        = 397
    SHMDT                        = 398
    MSGGET                       = 399
    MSGSND                       = 400
    MSGRCV                       = 401
    MSGCTL                       = 402
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
    @[AlwaysInline]
    def self.{{name.id}}({{*args}}) : {{return_type}}
      ret = uninitialized {{return_type}}

      {% if args.size == 0 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}})
                        : "memory"
                        : "volatile")
      {% elsif args.size == 1 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{ebx}"({{args[0].var.id}})
                        : "memory"
                        : "volatile")
      {% elsif args.size == 2 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{ebx}"({{args[0].var.id}}), "{ecx}"({{args[1].var.id}})
                        : "memory"
                        : "volatile")
      {% elsif args.size == 3 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{ebx}"({{args[0].var.id}}), "{ecx}"({{args[1].var.id}}),
                          "{edx}"({{args[2].var.id}})
                        : "memory"
                        : "volatile")
      {% elsif args.size == 4 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{ebx}"({{args[0].var.id}}), "{ecx}"({{args[1].var.id}}),
                          "{edx}"({{args[2].var.id}}), "{esi}"({{args[3].var.id}})
                        : "memory"
                        : "volatile")
      {% elsif args.size == 5 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{ebx}"({{args[0].var.id}}), "{ecx}"({{args[1].var.id}}),
                          "{edx}"({{args[2].var.id}}), "{esi}"({{args[3].var.id}}), "{edi}"({{args[4].var.id}})
                        : "memory"
                        : "volatile")
      {% elsif args.size == 6 %}
        asm("int $$0x80" : "={eax}"(ret)
                        : "{eax}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{ebx}"({{args[0].var.id}}), "{ecx}"({{args[1].var.id}}),
                          "{edx}"({{args[2].var.id}}), "{esi}"({{args[3].var.id}}), "{edi}"({{args[4].var.id}}), "{ebp}"({{args[5].var.id}})
                        : "memory"
                        : "volatile")
      {% else %}
        {% raise "Not supported number of arguments for syscall" %}
      {% end %}

      ret
    end
  end
end
