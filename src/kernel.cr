require "c/unistd"

STDIN  = IO::FileDescriptor.new(0, blocking: LibC.isatty(0) == 0)
STDOUT = (IO::FileDescriptor.new(1, blocking: LibC.isatty(1) == 0)).tap { |f| f.flush_on_newline = true }
STDERR = (IO::FileDescriptor.new(2, blocking: LibC.isatty(2) == 0)).tap { |f| f.flush_on_newline = true }

PROGRAM_NAME = String.new(ARGV_UNSAFE.value)
ARGV         = (ARGV_UNSAFE + 1).to_slice(ARGC_UNSAFE - 1).map { |c_str| String.new(c_str) }
ARGF         = IO::ARGF.new(ARGV, STDIN)

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
def gets(*args, **options)
  STDIN.gets(*args, **options)
end

# Reads a line from STDIN. See `IO#read_line`.
def read_line(*args, **options)
  STDIN.read_line(*args, **options)
end

# Prints objects to STDOUT and then invokes `STDOUT.flush`. See `IO#print`.
def print(*objects : _)
  STDOUT.print *objects
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
    String::Formatter(typeof(args)).new(format_string, args, str).format
  end
end

# Prints objects to STDOUT, each followed by a newline. See `IO#puts`.
def puts(*objects)
  STDOUT.puts *objects
end

# Pretty prints *object* to STDOUT followed
# by a newline. Returns *object*.
#
# See `Object#pretty_print(pp)`
def p(object)
  PrettyPrint.format(object, STDOUT, 79)
  puts
  object
end

# Pretty prints each object in *objects* to STDOUT, followed
# by a newline. Returns *objects*.
#
# See `Object#pretty_print(pp)`
def p(*objects)
  objects.each do |obj|
    p obj
  end
  objects
end

# :nodoc:
module AtExitHandlers
  @@running = false

  def self.add(handler)
    handlers = @@handlers ||= [] of Int32 ->
    handlers << handler
  end

  def self.run(status)
    return if @@running
    @@running = true

    @@handlers.try &.reverse_each do |handler|
      begin
        handler.call status
      rescue handler_ex
        STDERR.puts "Error running at_exit handler: #{handler_ex}"
      end
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
def at_exit(&handler : Int32 ->)
  AtExitHandlers.add(handler)
end

# Terminates execution immediately, returning the given status code
# to the invoking environment.
#
# Registered `at_exit` procs are executed.
def exit(status = 0)
  AtExitHandlers.run status
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
  def self.after_fork_child_callbacks
    @@after_fork_child_callbacks ||= [
      ->{ Scheduler.after_fork; nil },
      ->{ Event::SignalHandler.after_fork; nil },
      ->{ Event::SignalChildHandler.instance.after_fork; nil },
      ->{ Random::DEFAULT.new_seed; nil },
    ] of -> Nil
  end
end

Signal.setup_default_handlers

at_exit { Event::SignalHandler.close }

# Background loop to cleanup unused fiber stacks
spawn do
  loop do
    sleep 5
    Fiber.stack_pool_collect
  end
end
