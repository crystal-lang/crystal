{% skip_file unless flag?(:unix) %}

# On UNIX-like systems, the loader implementation is based on `libdl` .
# It tries to imitate the behaviour of `ld.so` (linux`, BSDs) and `ld` (darwin).
#
# There are a number of differences compared to linking object files in a normal
# object file linking process. Most are caused by limitations of `libdl`.
#
# * Only dynamic libraries can be loaded. Static libraries and object files
#   are unsupported.
# * All libraries are loaded into the same namespace. That means libraries
#   loaded in the compiler program itself may provide symbols to libraries
#   loaded with `Crystal::Loader`. Symbols may be available without explicitly
#   mentioning their libraries. It might be impossible to link against other
#   version of the libraries that the compiler is linked against.
# * A fully statically linked compiler may help dealing with the previous
#   issue. But using `libdl` in a non-dynamically loaded executable might cause
#   other issues.

class Crystal::Loader
  alias Handle = Void*

  class LoadError
    def self.new_dl_error(message)
      if char_pointer = LibC.dlerror
        new(String.build do |io|
          io << message
          io << " ("
          io.write_string(Slice.new(char_pointer, LibC.strlen(char_pointer)))
          io << ")"
        end)
      else
        new message
      end
    end
  end

  def initialize(@search_paths : Array(String))
  end

  # Parses linker arguments in the style of `ld`.
  #
  # *dll_search_paths* has no effect. (Technically speaking, `LD_LIBRARY_PATH`
  # goes here and `LIBRARY_PATH` goes into *search_paths*, but there is little
  # point in doing so since the same library files are used at both compile and
  # run time.)
  def self.parse(args : Array(String), *, search_paths : Array(String) = default_search_paths, dll_search_paths : Array(String)? = nil) : self
    libnames = [] of String
    file_paths = [] of String

    # `man ld(1)` on Linux:
    #
    # > -L searchdir
    # > ... The directories are searched in the order in which they are
    # specified on the command line. Directories specified on the command line
    # are searched before the default directories.
    #
    # `man ld(1)` on macOS:
    #
    # > -Ldir
    # > ... Directories specified with -L are searched in the order they appear
    # > on the command line and before the default search path...
    extra_search_paths = [] of String

    # OptionParser removes items from the args array, so we dup it here in order to produce a meaningful error message.
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
        file_paths.concat args
      end

      # although flags starting with `-Wl,` appear in `args` above, this is
      # still called by `OptionParser`, so we assume it is fine to ignore these
      # flags
      parser.invalid_option do |arg|
        unless arg.starts_with?("-Wl,")
          raise LoadError.new "Not a recognized linker flag: #{arg}"
        end
      end
    end

    search_paths = extra_search_paths + search_paths

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
    {% if flag?(:darwin) %}
      "lib#{libname}.dylib"
    {% else %}
      "lib#{libname}.so"
    {% end %}
  end

  def find_symbol?(name : String) : Handle?
    @handles.each do |handle|
      address = LibC.dlsym(handle, name)
      return address if address
    end
  end

  def load_file(path : String | ::Path) : Nil
    load_file?(path) || raise LoadError.new_dl_error "cannot load #{path}"
  end

  def load_file?(path : String | ::Path) : Bool
    handle = open_library(path.to_s)
    return false unless handle

    @handles << handle
    @loaded_libraries << path.to_s
    true
  end

  def load_library(libname : String) : Nil
    load_library?(libname) || raise LoadError.new_dl_error "cannot find -l#{libname}"
  end

  private def open_library(path : String)
    LibC.dlopen(path, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
  end

  def load_current_program_handle
    if program_handle = LibC.dlopen(nil, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
      @handles << program_handle
      @loaded_libraries << (Process.executable_path || "current program handle")
    end
  end

  # Closes all libraries loaded with this loader instance.
  #
  # Libraries are only unloaded when there are no references left.
  def close_all : Nil
    @handles.each do |handle|
      LibC.dlclose(handle)
    end
    @handles.clear
  end

  # Returns a list of directories used as the default search paths
  def self.default_search_paths : Array(String)
    default_search_paths = [] of String

    # TODO: respect the compiler's DT_RPATH (#13490)

    if env_library_path = ENV[{{ flag?(:darwin) ? "DYLD_LIBRARY_PATH" : "LD_LIBRARY_PATH" }}]?
      # TODO: Expand tokens $ORIGIN, $LIB, $PLATFORM
      default_search_paths.concat env_library_path.split(Process::PATH_DELIMITER, remove_empty: true)
    end

    # TODO: respect the compiler's DT_RUNPATH
    # TODO: respect $DYLD_FALLBACK_LIBRARY_PATH and the compiler's LC_RPATH on darwin

    {% if (flag?(:linux) && !flag?(:android)) || flag?(:bsd) %}
      read_ld_conf(default_search_paths)
    {% end %}

    cc_each_library_path do |path|
      default_search_paths << path
    end

    {% if flag?(:darwin) %}
      default_search_paths << "/usr/lib"
      default_search_paths << "/usr/local/lib"
    {% elsif flag?(:android) %}
      default_search_paths << "/vendor/lib64" if File.directory?("/vendor/lib64")
      default_search_paths << "/system/lib64" if File.directory?("/system/lib64")
      default_search_paths << "/vendor/lib"
      default_search_paths << "/system/lib"
    {% else %}
      {% if flag?(:linux) %}
        default_search_paths << "/lib64" if File.directory?("/lib64")
        default_search_paths << "/usr/lib64" if File.directory?("/usr/lib64")
      {% end %}
      default_search_paths << "/lib"
      default_search_paths << "/usr/lib"
    {% end %}

    default_search_paths.uniq!
  end

  def self.read_ld_conf(array = [] of String, path = "/etc/ld.so.conf") : Nil
    return unless File::Info.readable?(path)

    File.each_line(path) do |line|
      next if line.empty? || line.starts_with?("#")

      if include_path = line.lchop?("include ")
        glob = ::Path[include_path]

        # expand glob path relative to current config file
        glob = glob.expand(File.dirname(path))
        Dir.glob(glob) do |dir|
          read_ld_conf(array, dir)
        end
      else
        array << line.strip
      end
    end
  end

  def self.cc_each_library_path(& : String ->) : Nil
    search_dirs = begin
      `#{Crystal::Compiler::DEFAULT_LINKER} -print-search-dirs`
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
