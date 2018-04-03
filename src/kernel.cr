{% if flag?(:win32) %}
  STDIN  = IO::FileDescriptor.new(0)
  STDOUT = (IO::FileDescriptor.new(1)).tap { |f| f.flush_on_newline = true }
  STDERR = (IO::FileDescriptor.new(2)).tap { |f| f.flush_on_newline = true }
{% else %}
  require "c/unistd"

  STDIN  = IO::FileDescriptor.new(0, blocking: LibC.isatty(0) == 0)
  STDOUT = (IO::FileDescriptor.new(1, blocking: LibC.isatty(1) == 0)).tap { |f| f.flush_on_newline = true }
  STDERR = (IO::FileDescriptor.new(2, blocking: LibC.isatty(2) == 0)).tap { |f| f.flush_on_newline = true }
{% end %}

PROGRAM_NAME = String.new(ARGV_UNSAFE.value)
ARGV         = Array.new(ARGC_UNSAFE - 1) { |i| String.new(ARGV_UNSAFE[1 + i]) }
ARGF         = IO::ARGF.new(ARGV, STDIN)

# Repeatedly executes the block, passing an incremental `Int32`
# that starts with `0`.
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

# Reads a line from `STDIN`.
#
# See also: `IO#gets`.
def gets(*args, **options)
  STDIN.gets(*args, **options)
end

# Reads a line from `STDIN`.
#
# See also: `IO#read_line`.
def read_line(*args, **options)
  STDIN.read_line(*args, **options)
end

# Prints objects to STDOUT and then invokes `STDOUT.flush`.
#
# See also: `IO#print`.
def print(*objects : _) : Nil
  STDOUT.print *objects
  STDOUT.flush
end

# Prints a formatted string to `STDOUT`.
#
# For details on the format string, see `sprintf`.
def printf(format_string, *args) : Nil
  printf format_string, args
end

# ditto
def printf(format_string, args : Array | Tuple) : Nil
  STDOUT.printf format_string, args
end

# Returns a formatted string.
# The string is produced according to the *format_string* with format specifiers
# being replaced by values from *args* formatted according to the specifier.
# Within the format string, any characters other than format specifiers
# (specifiers beginning with %) are copied to the result.
#
# The syntax for a format specifier is:
#
# ```
# %[flags][width][.precision]type
# ```
#
# A format specifier consists of a percent sign, followed by optional flags,
# width, and precision indicators, then terminated with a field type
# character.  The field type controls how the corresponding
# `sprintf` argument is to be interpreted, while the flags
# modify that interpretation.
#
# The field type characters are:
# ```
#     Field |  Integer Format
#     ------+--------------------------------------------------------------
#       b   | Formats argument as a binary number.
#       d   | Formats argument as a decimal number.
#       i   | Same as `d`.
#       o   | Formats argument as an octal number.
#       x   | Formats argument as a hexadecimal number using lowercase letters.
#       X   | Same as `x`, but uses uppercase letters.
#
#     Field |  Float Format
#     ------+--------------------------------------------------------------
#       e   | Formats floating point argument into exponential notation
#           | with one digit before the decimal point as [-]d.dddddde[+-]dd.
#           | The precision specifies the number of digits after the decimal
#           | point (defaulting to six).
#       E   | Equivalent to `e`, but uses an uppercase E to indicate
#           | the exponent.
#       f   | Formats floating point argument as [-]ddd.dddddd,
#           | where the precision specifies the number of digits after
#           | the decimal point.
#       g   | Formats a floating point number using exponential form
#           | if the exponent is less than -4 or greater than or
#           | equal to the precision, or in dd.dddd form otherwise.
#           | The precision specifies the number of significant digits.
#       G   | Equivalent to `g`, but use an uppercase `E` in exponent form.
#       a   | Formats floating point argument as [-]0xh.hhhhp[+-]dd,
#           | which is consisted from optional sign, "0x", fraction part
#           | as hexadecimal, "p", and exponential part as decimal.
#       A   | Equivalent to `a`, but use uppercase `X` and `P`.
#
#     Field |  Other Format
#     ------+--------------------------------------------------------------
#       c   | Argument is the numeric code for a single character or
#           | a single character string itself.
#       s   | Argument is a string to be substituted.  If the format
#           | sequence contains a precision, at most that many characters
#           | will be copied.
#       %   | A percent sign itself will be displayed.  No argument taken.
# ```
# The flags modifies the behavior of the formats.
# The flag characters are:
# ```
#   Flag     | Applies to    | Meaning
#   ---------+---------------+-----------------------------------------
#   space    | bdiouxX       | Leave a space at the start of
#            | aAeEfgG       | non-negative numbers.
#            | (numeric fmt) | For `o`, `x`, `X`, `b`, use
#            |               | a minus sign with absolute value for
#            |               | negative values.
#   ---------+---------------+-----------------------------------------
#    #       | boxX          | ?
#   ---------+---------------+-----------------------------------------
#   +        | bdiouxX       | Add a leading plus sign to non-negative
#            | aAeEfgG       | numbers.
#            | (numeric fmt) | For `o`, `x`, `X`, `b`, use
#            |               | a minus sign with absolute value for
#            |               | negative values.
#   ---------+---------------+-----------------------------------------
#   -        | all           | Left-justify the result of this conversion.
#   ---------+---------------+-----------------------------------------
#   0 (zero) | bdiouxX       | Pad with zeros, not spaces.
#            | aAeEfgG       | For `o`, `x`, `X`, `b`, radix-1
#            | (numeric fmt) | is used for negative numbers formatted as
#            |               | complements.
# ```
#
# Examples of flags:
#
# Decimal number conversion
# ```
# sprintf "%d", 123  # => "123"
# sprintf "%+d", 123 # => "+123"
# sprintf "% d", 123 # => " 123"
# ```
#
# Octal number conversion
# ```
# sprintf "%o", 123   # => "173"
# sprintf "%+o", 123  # => "+173"
# sprintf "%o", -123  # => "-173"
# sprintf "%+o", -123 # => "-173"
# ```
#
# Hexadecimal number conversion
# ```
# sprintf "%x", 123   # => "7b"
# sprintf "%+x", 123  # => "+7b"
# sprintf "%x", -123  # => "-7b"
# sprintf "%+x", -123 # => "-7b"
# sprintf "%#x", 0    # => "0"
# sprintf "% x", 123  # => " 7b"
# sprintf "% x", -123 # => "-7b"
# sprintf "%X", 123   # => "7B"
# sprintf "%#X", -123 # => "-7B"
# ```
#
# Binary number conversion
# ```
# sprintf "%b", 123    # => "1111011"
# sprintf "%+b", 123   # => "+1111011"
# sprintf "%+b", -123  # => "-1111011"
# sprintf "%b", -123   # => "-1111011"
# sprintf "%#b", 0     # => "0"
# sprintf "% b", 123   # => " 1111011"
# sprintf "%+ b", 123  # => "+ 1111011"
# sprintf "% b", -123  # => "-1111011"
# sprintf "%+ b", -123 # => "-1111011"
# ```
#
# Floating point conversion
# ```
# sprintf "%a", 123 # => "0x1.ecp+6"
# sprintf "%A", 123 # => "0X1.ECP+6"
# ```
#
# Exponential form conversion
# ```
# sprintf "%g", 123.4          # => "123.4"
# sprintf "%g", 123.4567       # => "123.457"
# sprintf "%20.8g", 1234.56789 # => "           1234.5679"
# sprintf "%20.8g", 123456789  # => "       1.2345679e+08"
# sprintf "%20.8G", 123456789  # => "       1.2345679E+08"
# sprintf "%20.8g", -123456789 # => "       -1.2345679e+08"
# sprintf "%20.8G", -123456789 # => "       -1.2345679E+08"
# ```
#
# The field width is an optional integer, followed optionally by a
# period and a precision.  The width specifies the minimum number of
# characters that will be written to the result for this field.
#
# Examples of width:
# ```
# sprintf "%20d", 123   # => "                 123"
# sprintf "%+20d", 123  # => "                +123"
# sprintf "%020d", 123  # => "00000000000000000123"
# sprintf "%+020d", 12  # => "+0000000000000000123"
# sprintf "% 020d", 123 # => " 0000000000000000123"
# sprintf "%-20d", 123  # => "123                 "
# sprintf "%-+20d", 123 # => "+123                "
# sprintf "%- 20d", 123 # => " 123                "
# sprintf "%020x", -123 # => "00000000000000000-7b"
# sprintf "%020X", -123 # => "00000000000000000-7B"
# ```
#
# For numeric fields, the precision controls the number of decimal places
# displayed.  For string fields, the precision determines the maximum
# number of characters to be copied from the string.  (Thus, the format
# sequence <code>%10.10s</code> will always contribute exactly ten
# characters to the result.)
#
# Examples of precisions:
#
# precision for `d`, `o`, `x` and `b` is
# minimum number of digits
# ```
# sprintf "%20.8d", 123   # => "                 123"
# sprintf "%020.8d", 123  # => "00000000000000000123"
# sprintf "%20.8o", 123   # => "                 173"
# sprintf "%020.8o", 123  # => "00000000000000000173"
# sprintf "%20.8x", 123   # => "                  7b"
# sprintf "%020.8x", 123  # => "0000000000000000007b"
# sprintf "%20.8b", 123   # => "            01111011"
# sprintf "%20.8d", -123  # => "                -123"
# sprintf "%020.8d", -123 # => "0000000000000000-123"
# sprintf "%20.8o", -123  # => "                -173"
# sprintf "%20.8x", -123  # => "                 -7b"
# sprintf "%20.8b", -11   # => "               -1011"
# ```
#
# precision for `e` is number of
# digits after the decimal point
# ```
# sprintf "%20.8e", 1234.56789 # => "      1.23456789e+03"
# ```
#
# precision for `f` is number of
# digits after the decimal point
# ```
# sprintf "%20.8f", 1234.56789 # => "       1234.56789000"
# ```
#
# precision for `g` is number of
# significant digits
# ```
# sprintf "%20.8g", 1234.56789 # => "           1234.5679"
# sprintf "%20.8g", 123456789  # => "       1.2345679e+08"
# sprintf "%-20.8g", 123456789 # => "1.2345679e+08       "
# ```
#
# precision for `s` is
# maximum number of characters
# ```
# sprintf "%20.8s", "string test" # => "            string t"
# ```
#
# Additional examples:
# ```
# sprintf "%d %04x", 123, 123             # => "123 007b"
# sprintf "%08b '%4s'", 123, 123          # => "01111011 ' 123'"
# sprintf "%+g:% g:%-g", 1.23, 1.23, 1.23 # => "+1.23: 1.23:1.23"
# ```
def sprintf(format_string, *args) : String
  sprintf format_string, args
end

# ditto
def sprintf(format_string, args : Array | Tuple) : String
  String.build(format_string.bytesize) do |str|
    String::Formatter(typeof(args)).new(format_string, args, str).format
  end
end

# Prints objects to `STDOUT`, each followed by a newline.
#
# See also: `IO#puts`.
def puts(*objects) : Nil
  STDOUT.puts *objects
end

# Pretty prints *object* to `STDOUT` followed
# by a newline. Returns *object*.
#
# See also: `Object#pretty_print(pp)`.
def p(object)
  PrettyPrint.format(object, STDOUT, 79)
  puts
  object
end

# Pretty prints each object in *objects* to `STDOUT`, followed
# by a newline. Returns *objects*.
#
# See also: `Object#pretty_print(pp)`.
def p(*objects)
  objects.each do |obj|
    p obj
  end
  objects
end

# Pretty prints each object in *objects* to `STDOUT`, followed
# by a newline. Returns *objects*.
#
# ```
# p foo: 23, bar: 42 # => {foo: 23, bar: 42}
# ```
#
# See `Object#pretty_print(pp)`
def p(**objects)
  p(objects) unless objects.empty?
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
def at_exit(&handler : Int32 ->) : Nil
  AtExitHandlers.add(handler)
end

# Terminates execution immediately, returning the given status code
# to the invoking environment.
#
# Registered `at_exit` procs are executed.
def exit(status = 0) : NoReturn
  AtExitHandlers.run status
  STDOUT.flush
  STDERR.flush
  Process.exit(status)
end

# Terminates execution immediately, printing *message* to `STDERR` and
# then calling `exit(status)`.
def abort(message, status = 1) : NoReturn
  STDERR.puts message if message
  exit status
end

class Process
  # Hooks are defined here due to load order problems.
  def self.after_fork_child_callbacks
    @@after_fork_child_callbacks ||= [
      ->Scheduler.after_fork,
      ->Crystal::Signal.after_fork,
      ->Crystal::SignalChildHandler.after_fork,
      ->Random::DEFAULT.new_seed,
    ] of -> Nil
  end
end

{% unless flag?(:win32) %}
  # Background loop to cleanup unused fiber stacks.
  spawn do
    loop do
      sleep 5
      Fiber.stack_pool_collect
    end
  end

  Signal.setup_default_handlers
  LibExt.setup_sigfault_handler
{% end %}
