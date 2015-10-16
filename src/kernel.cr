STDIN = IO::FileDescriptor.new(0, blocking: LibC.isatty(0) == 0)
STDOUT = (IO::FileDescriptor.new(1, blocking: LibC.isatty(1) == 0)).tap { |f| f.flush_on_newline = true }
STDERR = IO::FileDescriptor.new(2, blocking: LibC.isatty(2) == 0)

PROGRAM_NAME = String.new(ARGV_UNSAFE.value)
ARGV = (ARGV_UNSAFE + 1).to_slice(ARGC_UNSAFE - 1).map { |c_str| String.new(c_str) }
ARGF = IO::ARGF.new(ARGV, STDIN)

# Repeatedly executes the block, passing an incremental `Int32`
# that starts with 0.
#
# ```
# loop do |i|
#   print "#{i}) "
#   line = gets
#   break unless line
#   # ...
# end
# ```
def loop
  i = 0
  while true
    yield i
    i += 1
  end
end

# Reads a line from STDIN. See `IO#gets`.
def gets(*args)
  STDIN.gets(*args)
end

# Reads a line from STDIN. See `IO#read_line`.
def read_line(*args)
  STDIN.read_line(*args)
end

# Prints objects to STDOUT. See `IO#print`.
def print(*objects : _)
  STDOUT.print *objects
end

# Prints objects to STDOUT and then invokes `STDOUT.flush`. See `IO#print`.
def print!(*objects : _)
  print *objects
  STDOUT.flush
  nil
end

# Prints a formatted string to STDOUT. See `IO#printf`.
def printf(format_string, *args)
  printf format_string, args
end

# ditto
def printf(format_string, args : Array | Tuple)
  STDOUT.printf format_string, args
end

# Returns a formatted string. See `IO#printf`.
def sprintf(format_string, *args) : String
  sprintf format_string, args
end

# ditto
def sprintf(format_string, args : Array | Tuple) : String
  String.build(format_string.bytesize) do |str|
    String::Formatter.new(format_string, args, str).format
  end
end

# Prints objects to STDOUT, each followed by a newline. See `IO#puts`.
def puts(*objects)
  STDOUT.puts *objects
end

# Prints *obj* to STDOUT by invoking `inspect(io)` on it, and followed
# by a newline.
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
      @@handlers.try &.reverse_each &.call
    rescue handler_ex
      puts "Error running at_exit handler: #{handler_ex}"
    end
  end
end

# Registers the given `Proc` for execution when the program exits.
# If multiple handlers are registered, they are executed in reverse order of registration.
#
# ```
# def do_at_exit(str1)
#   at_exit { print str1 }
# end
#
# at_exit { puts "cruel world" }
# do_at_exit("goodbye ")
# exit
# ```
#
# Produces:
#
# ```text
# goodbye cruel world
# ```
def at_exit(&handler)
  AtExitHandlers.add(handler)
end

# Terminates execution immediately, returning the given status code
# to the invoking environment.
#
# Registered `at_exit` procs are executed.
def exit(status = 0)
  AtExitHandlers.run
  STDOUT.flush
  STDERR.flush
  Process.exit(status)
end

# Terminates execution immediately, printing *message* to STDERR and
# then calling `exit(status)`.
def abort(message, status = 1)
  STDERR.puts message if message
  exit status
end

class Process
  # hooks defined here due to load order problems
  @@after_fork_child_callbacks = [
    -> { Scheduler.after_fork; nil },
    -> { Event::SignalHandler.after_fork; nil },
    -> { Event::SignalChildHandler.instance.after_fork; nil }
  ]
end

Signal::PIPE.ignore
Signal::CHLD.reset
at_exit { Event::SignalHandler.close }

# Background loop to cleanup unused fiber stacks
spawn do
  loop do
    sleep 5
    Fiber.stack_pool_collect
  end
end

