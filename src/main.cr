lib CrystalMain
  fun __crystal_main(argc : Int32, argv : Char**)
end

fun main(argc : Int32, argv : Char**) : Int32
  GC.init
  CrystalMain.__crystal_main(argc, argv)
  0
rescue ex
  puts ex
  1
end

