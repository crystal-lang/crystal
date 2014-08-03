lib CrystalMain
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

$at_exit_handlers = nil

def at_exit(&handler)
  handlers = $at_exit_handlers ||= [] of ->
  handlers << handler
end

def run_at_exit
  begin
    $at_exit_handlers.try &.each &.call
  rescue handler_ex
    puts "Error running at_exit handler: #{handler_ex}"
  end
end

macro redefine_main(name = main)
  fun main = {{name}}(argc : Int32, argv : UInt8**) : Int32
    GC.init
    {{yield CrystalMain.__crystal_main(argc, argv)}}
    0
  rescue ex
    puts ex
    ex.backtrace.each do |frame|
      puts frame
    end
    1
  ensure
    run_at_exit
  end
end

redefine_main do |main|
  {{main}}
end
