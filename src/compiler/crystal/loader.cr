{% skip_file unless flag?(:unix) || flag?(:msvc) %}
require "option_parser"

# This loader component imitates the behaviour of `ld.so` for linking and loading
# dynamic libraries at runtime.
#
# It provides a tool for interpreted mode, where the compiler does not generate
# an object file that could be passed to the linker. Instead, `Crystal::Loader`
# takes over the job of discovering libraries, loading them into memory and
# finding symbols inside them.
#
# See system-specific implementations in ./loader for details.
class Crystal::Loader
  class LoadError < Exception
    property args : Array(String)?
    property search_paths : Array(String)?

    def message
      String.build do |io|
        io << super
        if args = @args
          io << "\nLinker arguments: "
          args.join(io, " ")
        end
        if search_paths = @search_paths
          io << "\nSearch path: "
          search_paths.join(io, Process::PATH_DELIMITER)
        end
      end
    end
  end

  def self.new(search_paths : Array(String), libnames : Array(String), file_paths : Array(String)) : self
    loader = new(search_paths)

    file_paths.each do |path|
      loader.load_file(::Path[path].expand)
    end
    libnames.each do |libname|
      loader.load_library(libname)
    end
    loader
  end

  getter search_paths : Array(String)
  getter loaded_libraries = [] of String

  def initialize(@search_paths : Array(String))
    @handles = [] of Handle
  end

  # def self.library_filename(libname : String) : String
  #   raise NotImplementedError.new("library_filename")
  # end

  # def find_symbol?(name : String) : Handle?
  #   raise NotImplementedError.new("find_symbol?")
  # end

  # def load_file(path : String | ::Path) : Nil
  #   raise NotImplementedError.new("load_file")
  # end

  # def load_file?(path : String | ::Path) : Bool
  #   raise NotImplementedError.new("load_file?")
  # end

  # private def open_library(path : String) : Nil
  #   raise NotImplementedError.new("open_library")
  # end

  # def self.default_search_paths : Array(String)
  #   raise NotImplementedError.new("close_all")
  # end

  def find_symbol(name : String) : Handle
    find_symbol?(name) || raise LoadError.new "undefined reference to `#{name}'"
  end

  def load_library(libname : String) : Nil
    load_library?(libname) || raise LoadError.new "cannot find -l#{libname}"
  end

  def load_library?(libname : String) : Bool
    if ::Path::SEPARATORS.any? { |separator| libname.includes?(separator) }
      return load_file?(::Path[libname].expand)
    end

    @search_paths.each do |directory|
      library_path = File.join(directory, Loader.library_filename(libname))
      return true if load_file?(library_path)
    end

    false
  end

  def close_all : Nil
  end

  def finalize
    close_all
  end
end

{% if flag?(:unix) %}
  require "./loader/unix"
{% elsif flag?(:msvc) %}
  require "./loader/msvc"
{% end %}
