lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

macro redefine_main(name = main)
  fun main = {{name}}(argc : Int32, argv : UInt8**) : Int32
    %ex = nil
    begin
      GC.init
      {{yield LibCrystalMain.__crystal_main(argc, argv)}}
      %status = 0
    rescue ex
      %ex = ex
      %status = 1
    end

    AtExitHandlers.run %ex
    %ex.inspect_with_backtrace STDERR if %ex
    STDOUT.flush
    %status
  end
end

redefine_main do |main|
  {{main}}
end
