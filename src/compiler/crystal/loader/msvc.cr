{% skip_file unless flag?(:msvc) %}
require "crystal/system/win32/library_archive"

# On Windows with the MSVC toolset, the loader tries to imitate the behaviour of
# `link.exe`, using the Win32 DLL API.
#
# * Only dynamic libraries can be loaded. Static libraries and object files
#   are unsupported. For example, `LibC.printf` and `LibC.snprintf` are inline
#   functions in `legacy_stdio_definitions.lib` since VS2015, so they are never
#   found by the loader (this is why stdlib no longer uses those functions).
# * Unlike the Unix counterpart, symbols in the current module do not clash with
#   the ones in DLLs or their corresponding import libraries.

class Crystal::Loader
  alias Handle = Void*

  class LoadError
    include SystemError
  end

  getter dll_search_paths : Array(String)?

  def initialize(@search_paths : Array(String), @dll_search_paths : Array(String)? = nil)
  end

  # Parses linker arguments in the style of `link.exe`.
  #
  # The directories in *dll_search_paths* are tried before Windows' search order
  # when looking for DLLs corresponding to an import library. The compiler uses
  # this to mimic `@[Link]`'s DLL-copying behavior for compiled code.
  def self.parse(args : Array(String), *, search_paths : Array(String) = default_search_paths, dll_search_paths : Array(String)? = nil) : self
    search_paths, libnames = parse_args(args, search_paths)
    file_paths = [] of String

    begin
      loader = new(search_paths, dll_search_paths)
      loader.load_all(libnames, file_paths)
      loader
    rescue exc : LoadError
      exc.args = args
      exc.search_paths = search_paths
      exc.dll_search_paths = dll_search_paths
      raise exc
    end
  end

  struct SearchLibResult
    getter library_paths = [] of String
    getter remaining_args = [] of String
    getter(not_found) { [] of String }

    def not_found?
      @not_found
    end
  end

  # Extracts the command-line arguments from *args* that add libraries and
  # expands them to their absolute paths. Returns a `SearchLibResult` with those
  # expanded paths, plus unused arguments and libraries that were not found.
  def self.search_libraries(args : Array(String), *, search_paths : Array(String) = default_search_paths, extra_suffix : String? = nil) : SearchLibResult
    result = SearchLibResult.new
    search_paths, libnames = parse_args(args, search_paths, remaining: result.remaining_args)

    libnames.each do |libname|
      if found_path = search_library(libname, search_paths, extra_suffix)
        result.library_paths << found_path
      else
        result.not_found << libname
      end
    end

    result
  end

  protected def self.search_library(libname, search_paths, extra_suffix)
    if ::Path::SEPARATORS.any? { |separator| libname.includes?(separator) }
      libname = File.expand_path(libname)
      library_path = library_filename(libname)
      return library_path if File.file?(library_path)
    else
      search_paths.each do |directory|
        if extra_suffix
          library_path = File.join(directory, library_filename(libname + extra_suffix))
          return library_path if File.file?(library_path)
        end

        library_path = File.join(directory, library_filename(libname))
        return library_path if File.file?(library_path)
      end
    end
  end

  def self.parse_args(args, search_paths, *, remaining = nil)
    libnames = [] of String

    # NOTE: `/LIBPATH`s are prepended before the default paths:
    # (https://docs.microsoft.com/en-us/cpp/build/reference/libpath-additional-libpath)
    #
    # > ... The linker will first search in the path specified by this option,
    # > and then search in the path specified in the LIB environment variable.
    extra_search_paths = [] of String

    args.each do |arg|
      if !arg.starts_with?('/') && (name = arg.rchop?(".lib"))
        libnames << name
      else
        remaining << arg if remaining
        if lib_path = arg.lchop?("/LIBPATH:")
          extra_search_paths << lib_path
        end
      end
    end

    search_paths = extra_search_paths + search_paths
    search_paths.uniq! &.downcase
    libnames.uniq! &.downcase
    {search_paths, libnames}
  end

  def self.library_filename(libname : String) : String
    "#{libname.rchop(".lib")}.lib"
  end

  def find_symbol?(name : String) : Handle?
    @handles.each do |handle|
      address = LibC.GetProcAddress(handle, name.check_no_null_byte)
      return address if address
    end
  end

  def load_file(path : String | ::Path) : Nil
    load_file?(path) || raise LoadError.from_winerror "cannot load #{path}"
  end

  def load_file?(path : String | ::Path) : Bool
    return false unless File.file?(path)

    # On Windows, each `.lib` import library may reference any number of `.dll`
    # files, whose base names may not match the library's. Thus it is necessary
    # to extract this information from the library archive itself.
    System::LibraryArchive.imported_dlls(path).each do |dll|
      dll_full_path = @dll_search_paths.try &.each do |search_path|
        full_path = File.join(search_path, dll)
        break full_path if File.file?(full_path)
      end
      dll = dll_full_path || dll

      # TODO: `dll` is an unqualified name, e.g. `SHELL32.dll`, so the default
      # DLL search order is used if *dll_full_path* is nil; consider getting rid
      # of the current working directory altogether
      # (https://docs.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order)
      #
      # Note that the compiler's directory and PATH are effectively searched
      # twice when coming from the interpreter
      handle = open_library(dll)
      return false unless handle

      @handles << handle
      @loaded_libraries << (module_filename(handle) || dll)
    end

    true
  end

  def load_library(libname : String) : Nil
    load_library?(libname) || raise LoadError.from_winerror "cannot find #{Loader.library_filename(libname)}"
  end

  def load_library?(libname : String) : Bool
    library_path = Loader.search_library(libname, @search_paths, "-dynamic")
    !library_path.nil? && load_file?(library_path)
  end

  private def open_library(path : String)
    # TODO: respect Crystal::LIBRARY_RPATH (#13490), or `@[Link(dll:)]`'s search order
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
  # For MSVC this is simply the contents of the `LIB` environment variable,
  # usually pre-populated by the developer prompt. (If a normal prompt is used
  # but an MSVC installation is available, Crystal injects a replica of `LIB`'s
  # default contents through `/LIBPATH` linker arguments.)
  #
  # This is _not_ the same thing as the default search paths for `.dll` files.
  def self.default_search_paths : Array(String)
    if env_lib = ENV["LIB"]?
      env_lib.split(Process::PATH_DELIMITER, remove_empty: true)
    else
      [] of String
    end
  end
end
