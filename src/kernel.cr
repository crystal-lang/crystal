STDIN = BufferedIO.new(FileDescriptorIO.new(0, blocking: LibC.isatty(0) == 0, edge_triggerable: ifdef darwin; false; else; true; end))
STDOUT = AutoflushBufferedIO.new(FileDescriptorIO.new(1, blocking: LibC.isatty(1) == 0, edge_triggerable: ifdef darwin; false; else; true; end))
STDERR = FileDescriptorIO.new(2, blocking: LibC.isatty(2) == 0, edge_triggerable: ifdef darwin; false; else; true; end)

PROGRAM_NAME = String.new(ARGV_UNSAFE.value)
ARGV = (ARGV_UNSAFE + 1).to_slice(ARGC_UNSAFE - 1).map { |c_str| String.new(c_str) }

def loop
  while true
    yield
  end
end

def gets
  STDIN.gets
end

def gets(delimiter : Char)
  STDIN.gets(delimiter)
end

def gets(delimiter : String)
  STDIN.gets(delimiter)
end

def read_line
  STDIN.read_line
end

def read_line(delimiter : Char)
  STDIN.read_line(delimiter)
end

def read_line(delimiter : String)
  STDIN.read_line(delimiter)
end

def print(*objects : _)
  STDOUT.print *objects
end

def print!(*objects : _)
  print *objects
  STDOUT.flush
  nil
end

def printf(format_string, *args)
  printf format_string, args
end

def printf(format_string, args : Array | Tuple)
  STDOUT.printf format_string, args
end

def sprintf(format_string, *args)
  sprintf format_string, args
end

def sprintf(format_string, args : Array | Tuple)
  String.build(format_string.bytesize) do |str|
    String::Formatter.new(format_string, args, str).format
  end
end

def puts(*objects)
  STDOUT.puts *objects
end

def p(obj)
  obj.inspect(STDOUT)
  puts
  obj
end

# :nodoc:
module AtExitHandlers
  @@handlers = nil

  def self.add(handler)
    handlers = @@handlers ||= [] of ->
    handlers << handler
  end

  def self.run
    return if @@running
    @@running = true

    begin
      @@handlers.try &.each &.call
    rescue handler_ex
      puts "Error running at_exit handler: #{handler_ex}"
    end
  end
end

def at_exit(&handler)
  AtExitHandlers.add(handler)
end

def exit(status = 0)
  AtExitHandlers.run
  STDOUT.flush
  Process.exit(status)
end

def abort(message, status = 1)
  puts message
  exit status
end
