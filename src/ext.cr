@[Link(ldflags: "#{__DIR__}/ext/libcrystal.a")]
lib LibExt
  fun setup_sigfault_handler

  $debug_helper_func : ->
end

fun __crystal_debug_helper : Void
  if LibExt.debug_helper_func
    LibExt.debug_helper_func.call
  else
    STDERR.puts "Debug helper function not setup"
  end
end
