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
#
# A Windows implementation is not yet available.
class Crystal::Loader
  class LoadError < Exception
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

  def initialize(@search_paths : Array(String))
    @handles = [] of Handle
  end

  # def find_symbol?(name : String) : Handle?
  #   raise NotImplementedError.new("find_symbol?")
  # end

  # def load_file(path : String | ::Path) : Handle
  #   raise NotImplementedError.new("load_file")
  # end

  # private def open_library(path : String) : Handle
  #   raise NotImplementedError.new("open_library")
  # end

  # def self.default_search_paths : Array(String)
  #   raise NotImplementedError.new("close_all")
  # end

  def find_symbol(name : String) : Handle
    find_symbol?(name) || raise LoadError.new "undefined reference to `#{name}'"
  end

  def load_library(libname : String) : Handle
    load_library?(libname) || raise LoadError.new "cannot find -l#{libname}"
  end

  def load_library?(libname : String) : Handle?
    if ::Path::SEPARATORS.any? { |separator| libname.includes?(separator) }
      return load_file(::Path[libname].expand)
    end

    find_library_path(libname) do |library_path|
      handle = load_file?(library_path)
      return handle if handle
    end

    nil
  end

  def load_file?(path : String | ::Path) : Handle?
    handle = open_library(path.to_s)
    return nil unless handle

    @handles << handle
    handle
  end

  private def find_library_path(libname)
    each_library_path(libname) do |path|
      if File.exists?(path)
        yield path
      end
    end
  end

  private def each_library_path(libname)
    @search_paths.each do |directory|
      yield "#{directory}/lib#{libname}#{SHARED_LIBRARY_EXTENSION}"
    end
  end

  def close_all : Nil
  end

  def finalize
    close_all
  end

  SHARED_LIBRARY_EXTENSION = {% if flag?(:darwin) %}
                               ".dylib"
                             {% elsif flag?(:unix) %}
                               ".so"
                             {% elsif flag?(:windows) %}
                               ".dll"
                             {% else %}
      {% raise "Can't load dynamic libraries" %}
    {% end %}
end

{% if flag?(:unix) %}
  require "./loader/unix"
{% end %}
