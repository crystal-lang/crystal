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

  def initialize(@search_paths : Array(String), @dll_search_paths : Array(String)? = nil)
  end

  # Parses linker arguments in the style of `ld`.
  #
  # This is identical to the Unix loader. *dll_search_paths* is used to locate
  # DLLs by full path before falling back to bare-name loading.
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
      loader = new(search_paths, dll_search_paths)
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

    if ENV["CRYSTAL_INTERPRETER_LOADER_INFO"]?.presence
      STDERR.puts "  find_symbol?(#{name}): not found in #{@handles.size} handle(s)"
      @handles.each_with_index do |h, i|
        STDERR.puts "    handle[#{i}]=0x#{h.address.to_s(16)} lib=#{@loaded_libraries[i]? || "?"}"
      end
    end

    nil
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
    # For DLLs that are already loaded in the process (e.g. libpcre2-8-0.dll
    # as a load-time dep of crystal.exe), LoadLibraryExW with a bare name can
    # return a module handle that doesn't work with GetProcAddress.  Try
    # GetModuleHandleExW first: it returns the canonical HMODULE that the
    # Windows loader already tracks for the named DLL, and GetProcAddress works
    # on it reliably.
    via_get_module = false
    handle = if LibC.GetModuleHandleExW(0, System.to_wstr(dll), out existing) != 0
      via_get_module = true
      existing.as(Handle)
    else
      # DLL not yet in process: load by full path when possible to avoid the
      # same duplicate-handle issue if the DLL appears in the process later.
      full_path = resolve_dll_full_path(dll)
      open_library(full_path || dll)
    end

    if ENV["CRYSTAL_INTERPRETER_LOADER_INFO"]?.presence
      if handle
        STDERR.puts "  load_dll?(#{dll}): handle=0x#{handle.address.to_s(16)} via_GetModuleHandleExW=#{via_get_module} path=#{module_filename(handle) || "?"}"
      else
        STDERR.puts "  load_dll?(#{dll}): FAILED (handle is null)"
      end
    end

    return false unless handle

    @handles << handle
    @loaded_libraries << (module_filename(handle) || dll)
    true
  end

  # Searches for *dll* by full path in dll_search_paths and in sibling `bin/`
  # directories relative to each library search path.
  # Returns the full path if found, or nil to fall back to the bare name.
  private def resolve_dll_full_path(dll : String) : String?
    # Skip if it's already a path (contains a separator)
    return nil if ::Path::SEPARATORS.any? { |sep| dll.includes?(sep) }

    # Search in explicit dll_search_paths first
    @dll_search_paths.try &.each do |dir|
      path = File.join(dir, dll)
      return path if File.file?(path)
    end

    # Search in library search paths and their sibling bin/ directories.
    # In a typical MinGW layout, .dll.a files live in lib/ and .dll files in bin/,
    # so for each search path like D:\Crystal\lib\ we also check D:\Crystal\bin\.
    @search_paths.each do |lib_dir|
      bin_dir = File.join(::Path[lib_dir].parent.to_s, "bin")
      {% for dir in %w(bin_dir lib_dir) %}
        path = File.join({{dir.id}}, dll)
        return path if File.file?(path)
      {% end %}
    end

    nil
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
