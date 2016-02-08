{% system("make -C #{__DIR__}") %}

@[Link("ext", ldflags: "-L#{__DIR__}")]
lib LibExt
  fun setup_sigfault_handler
end
