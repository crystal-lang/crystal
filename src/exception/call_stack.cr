require "crystal/lru_cache"
require "sync/exclusive"

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

  @@loaded = false
  @@lru_cache = Sync::Exclusive(Crystal::LRUCache(Void*, String)).new(Crystal::LRUCache(Void*, String).new(1024))

  # :nodoc:
  def self.load_debug_info : Nil
    Crystal.once(pointerof(@@loaded)) do
      return if ENV["CRYSTAL_LOAD_DEBUG_INFO"]? == "0"

      begin
        load_debug_info_impl
      rescue ex
        Crystal::System.print_exception "Unable to load debug information", ex
      end
    end
  end

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
      CallStack.load_debug_info
      show_full_info = ENV["CRYSTAL_CALLSTACK_FULL_INFO"]? == "1"

      @callstack.compact_map do |ip|
        CallStack.decode_backtrace_frame(ip, show_full_info)
      end
    {% end %}
  end

  # :nodoc:
  def self.decode_backtrace_frame(ip, show_full_info) : String?
    line = @@lru_cache.lock(&.fetch?(ip))

    unless line
      pc = decode_address(ip)
      file, line_number, column_number = decode_line_number(pc)

      unless @@skip.includes?(file)
        file = relative_to_initial_directory(file)
        function, file = function_or_symbol_name(ip, file, show_full_info) { decode_function_name(pc) }
        line = format_backtrace_frame(file, line_number, column_number, function, show_full_info ? ip : nil)
      end

      @@lru_cache.lock(&.put(ip, line || ""))
    end

    line
  end

  private def self.format_backtrace_frame(file, line_number, column_number, function, ip) : String?
    return "???" if file == "??" && function == "??"

    String.build do |str|
      str << file

      unless file == "??" || line_number == 0
        str << ':'
        str << line_number

        unless column_number == 0
          str << ':'
          str << column_number
        end
      end

      str << " in '" << function << '\''

      if ip
        str << " at 0x"
        ip.address.to_s(str, 16)
      end
    end
  end

  private def self.function_or_symbol_name(ip, file, show_full_info, &)
    if show_full_info && (frame = decode_frame(ip))
      _, symbol, _ = frame
      return {symbol, file}
    end

    if function = yield
      return {function, file}
    end

    if !show_full_info && (frame = decode_frame(ip))
      _, symbol, file = frame
      # Crystal methods (their mangled name) start with `*`, so
      # we remove that to have less clutter in the output.
      symbol = symbol.lchop('*')
      return {symbol, file}
    end

    {"??", file}
  end

  private def self.relative_to_initial_directory(file)
    if file != "??" && (current_dir = CURRENT_DIR)
      if rel = Path[file].relative_to?(current_dir)
        rel = rel.to_s
        return rel unless rel.starts_with?("..")
      end
    end
    file
  end
end

{% if flag?(:interpreted) %}
  require "./call_stack/interpreter"
{% elsif flag?(:win32) && !flag?(:gnu) %}
  require "./call_stack/stackwalk"
{% elsif flag?(:wasm32) %}
  require "./call_stack/null"
{% else %}
  {% if flag?(:darwin) %}
    require "./call_stack/mach_o"
  {% elsif flag?(:win32) %}
    require "./call_stack/pe"
  {% else %}
    require "./call_stack/elf"
  {% end %}
  require "./call_stack/dwarf"
  require "./call_stack/libunwind"
{% end %}
