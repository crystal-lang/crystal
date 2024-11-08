{% skip_file unless flag?(:win32) && flag?(:gnu) %}

require "crystal/system/win32/library_archive"

# MinGW-based loader used on Windows. Assumes an MSYS2 shell.
#
# The core implementation is derived from the MSVC loader. Main deviations are:
#
# - `.parse` follows GNU `ld`'s style, rather than MSVC `link`'s;
# - `.parse` automatically inserts a C runtime library if `-mcrtdll` isn't
#   supplied;
# - `#library_filename` follows the usual naming of the MinGW linker: `.dll.a`
#   for DLL import libraries, `.a` for other libraries;
# - `.default_search_paths` relies solely on `.cc_each_library_path`.
#
# TODO: The actual MinGW linker supports linking to DLLs directly, figure out
# how this is done.

class Crystal::Loader
  alias Handle = Void*

  def initialize(@search_paths : Array(String))
  end

  # Parses linker arguments in the style of `ld`.
  #
  # This is identical to the Unix loader. *dll_search_paths* has no effect.
  def self.parse(args : Array(String), *, search_paths : Array(String) = default_search_paths, dll_search_paths : Array(String)? = nil) : self
    libnames = [] of String
    file_paths = [] of String
    extra_search_paths = [] of String

    # note that `msvcrt` is a default runtime chosen at MinGW-w64 build time,
    # `ucrt` is always UCRT (even in a MINGW64 environment), and
    # `msvcrt-os` is always MSVCRT (even in a UCRT64 environment)
    crt_dll = "msvcrt"

    OptionParser.parse(args.dup) do |parser|
      parser.on("-L DIRECTORY", "--library-path DIRECTORY", "Add DIRECTORY to library search path") do |directory|
        extra_search_paths << directory
      end
      parser.on("-l LIBNAME", "--library LIBNAME", "Search for library LIBNAME") do |libname|
        libnames << libname
      end
      parser.on("-static", "Do not link against shared libraries") do
        raise LoadError.new "static libraries are not supported by Crystal's runtime loader"
      end
      parser.unknown_args do |args, after_dash|
        file_paths.concat args.reject(&.starts_with?("-mcrtdll="))
      end

      parser.invalid_option do |arg|
        if crt_dll_arg = arg.lchop?("-mcrtdll=")
          # the GCC spec is `%{!mcrtdll=*:-lmsvcrt} %{mcrtdll=*:-l%*}`
          crt_dll = crt_dll_arg
        elsif !arg.starts_with?("-Wl,")
          raise LoadError.new "Not a recognized linker flag: #{arg}"
        end
      end
    end

    search_paths = extra_search_paths + search_paths
    libnames << crt_dll

    begin
      loader = new(search_paths)
      loader.load_all(libnames, file_paths)
      loader
    rescue exc : LoadError
      exc.args = args
      exc.search_paths = search_paths
      raise exc
    end
  end

  def self.library_filename(libname : String) : String
    "lib#{libname}.a"
  end

  def find_symbol?(name : String) : Handle?
    @handles.each do |handle|
      address = LibC.GetProcAddress(handle, name.check_no_null_byte)
      return address if address
    end
  end

  def load_file(path : String | ::Path) : Nil
    load_file?(path) || raise LoadError.new "cannot load #{path}"
  end

  def load_file?(path : String | ::Path) : Bool
    if api_set?(path)
      return load_dll?(path.to_s)
    end

    return false unless File.file?(path)

    System::LibraryArchive.imported_dlls(path).all? do |dll|
      load_dll?(dll)
    end
  end

  private def load_dll?(dll)
    handle = open_library(dll)
    return false unless handle

    @handles << handle
    @loaded_libraries << (module_filename(handle) || dll)
    true
  end

  def load_library(libname : String) : Nil
    load_library?(libname) || raise LoadError.new "cannot find #{Loader.library_filename(libname)}"
  end

  def load_library?(libname : String) : Bool
    if ::Path::SEPARATORS.any? { |separator| libname.includes?(separator) }
      return load_file?(::Path[libname].expand)
    end

    # attempt .dll.a before .a
    # TODO: verify search order
    @search_paths.each do |directory|
      library_path = File.join(directory, Loader.library_filename(libname + ".dll"))
      return true if load_file?(library_path)

      library_path = File.join(directory, Loader.library_filename(libname))
      return true if load_file?(library_path)
    end

    false
  end

  private def open_library(path : String)
    LibC.LoadLibraryExW(System.to_wstr(path), nil, 0)
  end

  def load_current_program_handle
    if LibC.GetModuleHandleExW(0, nil, out hmodule) != 0
      @handles << hmodule
      @loaded_libraries << (Process.executable_path || "current program handle")
    end
  end

  def close_all : Nil
    @handles.each do |handle|
      LibC.FreeLibrary(handle)
    end
    @handles.clear
  end

  private def api_set?(dll)
    dll.to_s.matches?(/^(?:api-|ext-)[a-zA-Z0-9-]*l\d+-\d+-\d+\.dll$/)
  end

  private def module_filename(handle)
    Crystal::System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC.GetModuleFileNameW(handle, buffer, buffer.size)
      if 0 < len < buffer.size
        break String.from_utf16(buffer[0, len])
      elsif small_buf && len == buffer.size
        next 32767 # big enough. 32767 is the maximum total path length of UNC path.
      else
        break nil
      end
    end
  end

  # Returns a list of directories used as the default search paths.
  #
  # Right now this depends on `cc` exclusively.
  def self.default_search_paths : Array(String)
    default_search_paths = [] of String

    cc_each_library_path do |path|
      default_search_paths << path
    end

    default_search_paths.uniq!
  end

  # identical to the Unix loader
  def self.cc_each_library_path(& : String ->) : Nil
    search_dirs = begin
      cc =
        {% if Crystal.has_constant?("Compiler") %}
          Crystal::Compiler::DEFAULT_LINKER
        {% else %}
          # this allows the loader to be required alone without the compiler
          ENV["CC"]? || "cc"
        {% end %}

      `#{cc} -print-search-dirs`
    rescue IO::Error
      return
    end

    search_dirs.each_line do |line|
      if libraries = line.lchop?("libraries: =")
        libraries.split(Process::PATH_DELIMITER) do |path|
          yield File.expand_path(path)
        end
      end
    end
  end
end
