lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

macro redefine_main(name = main)
  fun main = {{name}}(argc : Int32, argv : UInt8**) : Int32
    GC.init
    {{yield LibCrystalMain.__crystal_main(argc, argv)}}
    0
  rescue ex
    puts "#{ex} (#{ex.class})"
    ex.backtrace.each do |frame|
      puts frame
    end
    1
  ensure
    AtExitHandlers.run
    STDOUT.flush
  end
end

redefine_main do |main|
  {{main}}
end
