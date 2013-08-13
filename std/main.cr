lib CrystalMain
  fun main = __crystal_main(argc : Int32, argv : Char**)
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.main(argc, argv)
  0
rescue
  puts "Uncaught exception"
  1
end

