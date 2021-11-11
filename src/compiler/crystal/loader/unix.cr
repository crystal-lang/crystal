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
#   verions of the libraries that the compiler is linked against.
# * A fully statically linked compiler may help dealing with the previous
#   issue. But using `libdl` in a non-dynamically loaded executable might cause
#   other issues.

class Crystal::Loader
  alias Handle = Void*

  # Parses linker arguments in the style of `ld`.
  def self.parse(args : Array(String), *, search_paths : Array(String) = default_search_paths) : self
    libnames = [] of String
    file_paths = [] of String
    OptionParser.parse(args) do |parser|
      parser.on("-L DIRECTORY", "--library-path DIRECTORY", "Add DIRECTORY to library search path") do |directory|
        search_paths << directory
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
    end

    self.new(search_paths, libnames, file_paths)
  end

  def find_symbol?(name : String) : Handle?
    @handles.each do |handle|
      address = LibC.dlsym(handle, name)
      if address
        return address
      end
    end
  end

  def load_file(path : String | ::Path) : Handle
    load_file?(path) || raise LoadError.new String.new(LibC.dlerror)
  end

  private def open_library(path : String)
    LibC.dlopen(path, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
  end

  # Closes all libraries loaded with this loader instance.
  #
  # Libraries are only unloaded when there are no references left.
  def close_all : Nil
    @handles.each do |handle|
      LibC.dlclose(handle)
    end
  end

  # Returns a list of directors used as the default search paths
  def self.default_search_paths : Array(String)
    default_search_paths = [] of String

    if env_library_path = ENV[{{ flag?(:darwin) ? "DYLD_LIBRARY_PATH" : "LD_LIBRARY_PATH" }}]?
      # TODO: Expand tokens $ORIGIN, $LIB, $PLATFORM
      default_search_paths.concat env_library_path.split(Process::PATH_DELIMITER, remove_empty: true)
    end

    {% if flag?(:linux) || flag?(:bsd) %}
      read_ld_conf(default_search_paths)
    {% end %}

    {% if flag?(:darwin) %}
      default_search_paths << "/usr/lib"
      default_search_paths << "/usr/local/lib"
    {% else %}
      {% if flag?(:linux) %}
        default_search_paths << "/lib64" if File.directory?("/lib64")
        default_search_paths << "/usr/lib64" if File.directory?("/usr/lib64")
      {% end %}
      default_search_paths << "/lib"
      default_search_paths << "/usr/lib"
    {% end %}

    default_search_paths
  end

  def self.read_ld_conf(array = [] of String, path = "/etc/ld.so.conf") : Nil
    return unless File.readable?(path)

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
end
