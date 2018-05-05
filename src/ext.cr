@[Link(ldflags: "#{__DIR__}/ext/libcrystal.a")]
lib LibExt
  fun setup_sigfault_handler
  fun setup_alarm_handler
end
