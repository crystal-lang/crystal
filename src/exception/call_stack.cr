{% if flag?(:interpreted) %}
  require "./call_stack/interpreter"
{% elsif flag?(:win32) && !flag?(:gnu) %}
  require "./call_stack/stackwalk"
{% elsif flag?(:wasm32) %}
  require "./call_stack/null"
{% else %}
  require "./call_stack/libunwind"
{% end %}

# Returns the current execution stack as an array containing strings
# usually in the form file:line:column or file:line:column in 'method'.
def caller : Array(String)
  Exception::CallStack.new.printable_backtrace
end

# :nodoc:
struct Exception::CallStack
  # Compute current directory at the beginning so filenames
  # are always shown relative to the *starting* working directory.
  private CURRENT_DIR = Process::INITIAL_PWD.try { |dir| Path[dir] }

  @@skip = [] of String

  def self.skip(filename) : Nil
    @@skip << filename
  end

  skip(__FILE__)

  @callstack : Array(Void*)
  @backtrace : Array(String)?

  def initialize(@callstack : Array(Void*) = CallStack.unwind)
  end

  class_getter empty = new([] of Void*)

  def printable_backtrace : Array(String)
    @backtrace ||= decode_backtrace
  end

  private def decode_backtrace
    {% if flag?(:wasm32) %}
      [] of String
    {% else %}
      show_full_info = ENV["CRYSTAL_CALLSTACK_FULL_INFO"]? == "1"

      @callstack.compact_map do |ip|
        pc = CallStack.decode_address(ip)

        file, line_number, column_number = CallStack.decode_line_number(pc)

        if file && file != "??"
          next if @@skip.includes?(file)

          # Turn to relative to the current dir, if possible
          if current_dir = CURRENT_DIR
            if rel = Path[file].relative_to?(current_dir)
              rel = rel.to_s
              file = rel unless rel.starts_with?("..")
            end
          end

          file_line_column = file
          unless line_number == 0
            file_line_column = "#{file_line_column}:#{line_number}"
            file_line_column = "#{file_line_column}:#{column_number}" unless column_number == 0
          end
        end

        if name = CallStack.decode_function_name(pc)
          function = name
        elsif frame = CallStack.decode_frame(ip)
          _, function, file = frame
          # Crystal methods (their mangled name) start with `*`, so
          # we remove that to have less clutter in the output.
          function = function.lchop('*')
        else
          function = "??"
        end

        if file_line_column
          if show_full_info && (frame = CallStack.decode_frame(ip))
            _, sname, _ = frame
            line = "#{file_line_column} in '#{sname}'"
          else
            line = "#{file_line_column} in '#{function}'"
          end
        else
          if file == "??" && function == "??"
            line = "???"
          else
            line = "#{file} in '#{function}'"
          end
        end

        if show_full_info
          line = "#{line} at 0x#{ip.address.to_s(16)}"
        end

        line
      end
    {% end %}
  end
end
