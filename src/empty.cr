require "primitives"

{% if flag?(:win32) %}
  @[Link("libcmt")] # For `mainCRTStartup`
{% end %}
lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

fun main(argc : Int32, argv : UInt8**) : Int32
  LibCrystalMain.__crystal_main(argc, argv)
  0
end
