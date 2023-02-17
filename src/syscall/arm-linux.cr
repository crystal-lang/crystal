{% skip_file unless flag?(:linux) && flag?(:arm) && !flag?(:interpreted) %}

module Syscall
  # :nodoc:
  # Based on https://github.com/torvalds/linux/blob/master/arch/arm/tools/syscall.tbl
  enum Code : UInt32
    RESTART_SYSCALL              =   0
    EXIT                         =   1
    FORK                         =   2
    READ                         =   3
    WRITE                        =   4
    OPEN                         =   5
    CLOSE                        =   6
    CREAT                        =   8
    LINK                         =   9
    UNLINK                       =  10
    EXECVE                       =  11
    CHDIR                        =  12
    MKNOD                        =  14
    CHMOD                        =  15
    LCHOWN                       =  16
    LSEEK                        =  19
    GETPID                       =  20
    MOUNT                        =  21
    SETUID                       =  23
    GETUID                       =  24
    PTRACE                       =  26
    PAUSE                        =  29
    ACCESS                       =  33
    NICE                         =  34
    SYNC                         =  36
    KILL                         =  37
    RENAME                       =  38
    MKDIR                        =  39
    RMDIR                        =  40
    DUP                          =  41
    PIPE                         =  42
    TIMES                        =  43
    BRK                          =  45
    SETGID                       =  46
    GETGID                       =  47
    GETEUID                      =  49
    GETEGID                      =  50
    ACCT                         =  51
    UMOUNT2                      =  52
    IOCTL                        =  54
    FCNTL                        =  55
    SETPGID                      =  57
    UMASK                        =  60
    CHROOT                       =  61
    USTAT                        =  62
    DUP2                         =  63
    GETPPID                      =  64
    GETPGRP                      =  65
    SETSID                       =  66
    SIGACTION                    =  67
    SETREUID                     =  70
    SETREGID                     =  71
    SIGSUSPEND                   =  72
    SIGPENDING                   =  73
    SETHOSTNAME                  =  74
    SETRLIMIT                    =  75
    GETRUSAGE                    =  77
    GETTIMEOFDAY                 =  78
    SETTIMEOFDAY                 =  79
    GETGROUPS                    =  80
    SETGROUPS                    =  81
    SYMLINK                      =  83
    READLINK                     =  85
    USELIB                       =  86
    SWAPON                       =  87
    REBOOT                       =  88
    MUNMAP                       =  91
    TRUNCATE                     =  92
    FTRUNCATE                    =  93
    FCHMOD                       =  94
    FCHOWN                       =  95
    GETPRIORITY                  =  96
    SETPRIORITY                  =  97
    STATFS                       =  99
    FSTATFS                      = 100
    SYSLOG                       = 103
    SETITIMER                    = 104
    GETITIMER                    = 105
    STAT                         = 106
    LSTAT                        = 107
    FSTAT                        = 108
    VHANGUP                      = 111
    WAIT4                        = 114
    SWAPOFF                      = 115
    SYSINFO                      = 116
    FSYNC                        = 118
    SIGRETURN                    = 119
    CLONE                        = 120
    SETDOMAINNAME                = 121
    UNAME                        = 122
    ADJTIMEX                     = 124
    MPROTECT                     = 125
    SIGPROCMASK                  = 126
    INIT_MODULE                  = 128
    DELETE_MODULE                = 129
    QUOTACTL                     = 131
    GETPGID                      = 132
    FCHDIR                       = 133
    BDFLUSH                      = 134
    SYSFS                        = 135
    PERSONALITY                  = 136
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
    GETDENTS64                   = 217
    PIVOT_ROOT                   = 218
    MINCORE                      = 219
    MADVISE                      = 220
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
    IO_SETUP                     = 243
    IO_DESTROY                   = 244
    IO_GETEVENTS                 = 245
    IO_SUBMIT                    = 246
    IO_CANCEL                    = 247
    EXIT_GROUP                   = 248
    LOOKUP_DCOOKIE               = 249
    EPOLL_CREATE                 = 250
    EPOLL_CTL                    = 251
    EPOLL_WAIT                   = 252
    REMAP_FILE_PAGES             = 253
    SET_TID_ADDRESS              = 256
    TIMER_CREATE                 = 257
    TIMER_SETTIME                = 258
    TIMER_GETTIME                = 259
    TIMER_GETOVERRUN             = 260
    TIMER_DELETE                 = 261
    CLOCK_SETTIME                = 262
    CLOCK_GETTIME                = 263
    CLOCK_GETRES                 = 264
    CLOCK_NANOSLEEP              = 265
    STATFS64                     = 266
    FSTATFS64                    = 267
    TGKILL                       = 268
    UTIMES                       = 269
    ARM_FADVISE64_64             = 270
    PCICONFIG_IOBASE             = 271
    PCICONFIG_READ               = 272
    PCICONFIG_WRITE              = 273
    MQ_OPEN                      = 274
    MQ_UNLINK                    = 275
    MQ_TIMEDSEND                 = 276
    MQ_TIMEDRECEIVE              = 277
    MQ_NOTIFY                    = 278
    MQ_GETSETATTR                = 279
    WAITID                       = 280
    SOCKET                       = 281
    BIND                         = 282
    CONNECT                      = 283
    LISTEN                       = 284
    ACCEPT                       = 285
    GETSOCKNAME                  = 286
    GETPEERNAME                  = 287
    SOCKETPAIR                   = 288
    SEND                         = 289
    SENDTO                       = 290
    RECV                         = 291
    RECVFROM                     = 292
    SHUTDOWN                     = 293
    SETSOCKOPT                   = 294
    GETSOCKOPT                   = 295
    SENDMSG                      = 296
    RECVMSG                      = 297
    SEMOP                        = 298
    SEMGET                       = 299
    SEMCTL                       = 300
    MSGSND                       = 301
    MSGRCV                       = 302
    MSGGET                       = 303
    MSGCTL                       = 304
    SHMAT                        = 305
    SHMDT                        = 306
    SHMGET                       = 307
    SHMCTL                       = 308
    ADD_KEY                      = 309
    REQUEST_KEY                  = 310
    KEYCTL                       = 311
    SEMTIMEDOP                   = 312
    VSERVER                      = 313
    IOPRIO_SET                   = 314
    IOPRIO_GET                   = 315
    INOTIFY_INIT                 = 316
    INOTIFY_ADD_WATCH            = 317
    INOTIFY_RM_WATCH             = 318
    MBIND                        = 319
    GET_MEMPOLICY                = 320
    SET_MEMPOLICY                = 321
    OPENAT                       = 322
    MKDIRAT                      = 323
    MKNODAT                      = 324
    FCHOWNAT                     = 325
    FUTIMESAT                    = 326
    FSTATAT64                    = 327
    UNLINKAT                     = 328
    RENAMEAT                     = 329
    LINKAT                       = 330
    SYMLINKAT                    = 331
    READLINKAT                   = 332
    FCHMODAT                     = 333
    FACCESSAT                    = 334
    PSELECT6                     = 335
    PPOLL                        = 336
    UNSHARE                      = 337
    SET_ROBUST_LIST              = 338
    GET_ROBUST_LIST              = 339
    SPLICE                       = 340
    ARM_SYNC_FILE_RANGE          = 341
    TEE                          = 342
    VMSPLICE                     = 343
    MOVE_PAGES                   = 344
    GETCPU                       = 345
    EPOLL_PWAIT                  = 346
    KEXEC_LOAD                   = 347
    UTIMENSAT                    = 348
    SIGNALFD                     = 349
    TIMERFD_CREATE               = 350
    EVENTFD                      = 351
    FALLOCATE                    = 352
    TIMERFD_SETTIME              = 353
    TIMERFD_GETTIME              = 354
    SIGNALFD4                    = 355
    EVENTFD2                     = 356
    EPOLL_CREATE1                = 357
    DUP3                         = 358
    PIPE2                        = 359
    INOTIFY_INIT1                = 360
    PREADV                       = 361
    PWRITEV                      = 362
    RT_TGSIGQUEUEINFO            = 363
    PERF_EVENT_OPEN              = 364
    RECVMMSG                     = 365
    ACCEPT4                      = 366
    FANOTIFY_INIT                = 367
    FANOTIFY_MARK                = 368
    PRLIMIT64                    = 369
    NAME_TO_HANDLE_AT            = 370
    OPEN_BY_HANDLE_AT            = 371
    CLOCK_ADJTIME                = 372
    SYNCFS                       = 373
    SENDMMSG                     = 374
    SETNS                        = 375
    PROCESS_VM_READV             = 376
    PROCESS_VM_WRITEV            = 377
    KCMP                         = 378
    FINIT_MODULE                 = 379
    SCHED_SETATTR                = 380
    SCHED_GETATTR                = 381
    RENAMEAT2                    = 382
    SECCOMP                      = 383
    GETRANDOM                    = 384
    MEMFD_CREATE                 = 385
    BPF                          = 386
    EXECVEAT                     = 387
    USERFAULTFD                  = 388
    MEMBARRIER                   = 389
    MLOCK2                       = 390
    COPY_FILE_RANGE              = 391
    PREADV2                      = 392
    PWRITEV2                     = 393
    PKEY_MPROTECT                = 394
    PKEY_ALLOC                   = 395
    PKEY_FREE                    = 396
    STATX                        = 397
    RSEQ                         = 398
    IO_PGETEVENTS                = 399
    MIGRATE_PAGES                = 400
    KEXEC_FILE_LOAD              = 401
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
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}})
                      : "memory"
                      : "volatile")
      {% elsif args.size == 1 %}
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{r0}"({{args[0].var.id}})
                      : "memory"
                      : "volatile")
      {% elsif args.size == 2 %}
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{r0}"({{args[0].var.id}}), "{r1}"({{args[1].var.id}})
                      : "memory"
                      : "volatile")
      {% elsif args.size == 3 %}
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{r0}"({{args[0].var.id}}), "{r1}"({{args[1].var.id}}),
                        "{r2}"({{args[2].var.id}})
                      : "memory"
                      : "volatile")
      {% elsif args.size == 4 %}
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{r0}"({{args[0].var.id}}), "{r1}"({{args[1].var.id}}),
                        "{r2}"({{args[2].var.id}}), "{r3}"({{args[3].var.id}})
                      : "memory"
                      : "volatile")
      {% elsif args.size == 5 %}
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{r0}"({{args[0].var.id}}), "{r1}"({{args[1].var.id}}),
                        "{r2}"({{args[2].var.id}}), "{r3}"({{args[3].var.id}}), "{r4}"({{args[4].var.id}})
                      : "memory"
                      : "volatile")
      {% elsif args.size == 6 %}
        asm("swi 0x0" : "={r0}"(ret)
                      : "{r7}"(::Syscall::Code::{{name.stringify.upcase.id}}), "{r0}"({{args[0].var.id}}), "{r1}"({{args[1].var.id}}),
                        "{r2}"({{args[2].var.id}}), "{r3}"({{args[3].var.id}}), "{r4}"({{args[4].var.id}}), "{r5}"({{args[5].var.id}})
                      : "memory"
                      : "volatile")
      {% else %}
        {% raise "Not supported number of arguments for syscall" %}
      {% end %}

      ret
    end
  end
end
