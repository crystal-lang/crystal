# JSON pretty printer
# ~~~~~~~~~~~~~~~~~~~
#
# Reads JSON from STDIN and outputs it formatted and colored to STDOUT.
#
# Usage: echo '[1, {"two": "three"}, false]' | pretty_json

require "json"
require "colorize"

class PrettyPrinter
  def initialize(@input : IO, @output : IO)
    @pull = JSON::PullParser.new @input
    @indent = 0
  end

  def print
    read_any
  end

  def read_any
    case @pull.kind
    when :null
      with_color.bold.surround(@output) do
        @pull.read_null.to_json(@output)
      end
    when :bool
      with_color.light_blue.surround(@output) do
        @pull.read_bool.to_json(@output)
      end
    when :int
      with_color.red.surround(@output) do
        @pull.read_int.to_json(@output)
      end
    when :float
      with_color.red.surround(@output) do
        @pull.read_float.to_json(@output)
      end
    when :string
      with_color.yellow.surround(@output) do
        @pull.read_string.to_json(@output)
      end
    when :begin_array
      read_array
    when :begin_object
      read_object
    when :EOF
      # We are done
    end
  end

  def read_array
    print "[\n"
    @indent += 1
    i = 0
    @pull.read_array do
      if i > 0
        print ','
        print '\n' if @indent > 0
      end
      print_indent
      read_any
      i += 1
    end
    @indent -= 1
    print '\n'
    print_indent
    print ']'
  end

  def read_object
    print "{\n"
    @indent += 1
    i = 0
    @pull.read_object do |key|
      if i > 0
        print ','
        print '\n' if @indent > 0
      end
      print_indent
      with_color.cyan.surround(@output) do
        key.to_json(@output)
      end
      print ": "
      read_any
      i += 1
    end
    @indent -= 1
    print '\n'
    print_indent
    print '}'
  end

  def print_indent
    @indent.times { @output << "  " }
  end

  def print(value)
    @output << value
  end
end

printer = PrettyPrinter.new(STDIN, STDOUT)
printer.print
STDOUT.puts
