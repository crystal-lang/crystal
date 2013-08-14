lib CrystalMain
  fun __crystal_main(argc : Int32, argv : Char**)
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.__crystal_main(argc, argv)
  0
rescue
  puts "Uncaught exception"
  1
end

