lib CrystalMain
  fun __crystal_main(argc : Int32, argv : Char**)
end

$at_exit_handlers = nil

def at_exit(handler)
  handlers = $at_exit_handlers ||= [] of (-> Nil)
  handlers << handler
end

fun main(argc : Int32, argv : Char**) : Int32
  GC.init
  CrystalMain.__crystal_main(argc, argv)
  0
rescue ex
  puts ex
  1
ensure
  $at_exit_handlers.try &.each &.call
end

