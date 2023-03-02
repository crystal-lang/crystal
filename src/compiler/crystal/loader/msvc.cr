{% skip_file unless flag?(:msvc) %}
require "crystal/system/win32/library_archive"

# On Windows with the MSVC toolset, the loader tries to imitate the behaviour of
# `link.exe`, using the Win32 DLL API.
#
# * Only dynamic libraries can be loaded. Static libraries and object files
#   are unsupported. in particular, `LibC.printf` and `LibC.snprintf` are inline
#   functions in `legacy_stdio_definitions.lib` since VS2015, so they are never
#   found by the loader. As a temporary workaround, we re-export these two
#   functions via `etc/msvc/win32_interpreter_stub.c`.
# * Unlike the Unix counterpart, symbols in the current module do not clash with
#   the ones in DLLs or their corresponding import libraries.

class Crystal::Loader
  alias Handle = Void*

  class LoadError
    include SystemError
  end

  # Parses linker arguments in the style of `link.exe`.
  def self.parse(args : Array(String), *, search_paths : Array(String) = default_search_paths) : self
    libnames = [] of String
    file_paths = [] of String

    # NOTE: `/LIBPATH`s are prepended before the default paths:
    # (https://docs.microsoft.com/en-us/cpp/build/reference/libpath-additional-libpath)
    #
    # > ... The linker will first search in the path specified by this option,
    # > and then search in the path specified in the LIB environment variable.
    extra_search_paths = [] of String

    args.each do |arg|
      if lib_path = arg.lchop?("/LIBPATH:")
        extra_search_paths << lib_path
      elsif !arg.starts_with?('/') && (name = arg.rchop?(".lib"))
        libnames << name
      end
    end

    search_paths = extra_search_paths + search_paths

    begin
      self.new(search_paths, libnames, file_paths)
    rescue exc : LoadError
      exc.args = args
      exc.search_paths = search_paths
      raise exc
    end
  end

  def self.library_filename(libname : String) : String
    "#{libname}.lib"
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
      # always consider the `.dll` in the same directory as the `.lib` first,
      # regardless of the search order
      first_path = File.join(File.dirname(path), dll)
      dll = first_path if File.file?(first_path)

      # TODO: `dll` is an unqualified name, e.g. `SHELL32.dll`, so the default
      # DLL search order is used; consider getting rid of the cwd
      # (https://docs.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order)
      handle = open_library(dll)
      return false unless handle

      @handles << handle
      @loaded_libraries << dll
    end

    true
  end

  def load_library(libname : String) : Nil
    load_library?(libname) || raise LoadError.from_winerror "cannot find #{Loader.library_filename(libname)}"
  end

  private def open_library(path : String)
    LibC.LoadLibraryExW(System.to_wstr(path), nil, 0)
  end

  def load_current_program_handle
    if LibC.GetModuleHandleExW(0, nil, out hmodule) != 0
      @handles << hmodule
    end
  end

  def close_all : Nil
    @handles.each do |handle|
      LibC.FreeLibrary(handle)
    end
    @handles.clear
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
