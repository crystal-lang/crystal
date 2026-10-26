# wasi-libc's command startup obtains the program arguments and invokes this
# entry point. crt1-command.o supplies _start for every WASI preview.

@[Link(":crt1-command.o")]
lib LibC
end

fun __main_argc_argv(argc : Int32, argv : UInt8**) : Int32
  main(argc, argv)
end
