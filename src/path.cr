class Path
  # The file/directory separator character. '/' in unix, '\\' in windows.
  SEPARATOR = {% if flag?(:windows) %}
    '\\'
  {% else %}
    '/'
  {% end %}

  # The file/directory separator string. "/" in unix, "\\" in windows.
  SEPARATOR_STRING = {% if flag?(:windows) %}
    "\\"
  {% else %}
    "/"
  {% end %}

  include Comparable(Path)

  @path : String

  def initialize(path : String)
    @path = path.to_s
  end

  def initialize(path : Path)
    @path = path.value
  end

  def to_s : String
    @path
  end

  def <=>(other : Path)
    value <=> other.value
  end

  # Returns a new string formed by joining the strings using `Path::SEPARATOR`.
  #
  # ```
  # Path.join("foo", "bar", "baz")       # => "foo/bar/baz"
  # Path.join("foo/", "/bar/", "/baz")   # => "foo/bar/baz"
  # Path.join("/foo/", "/bar/", "/baz/") # => "/foo/bar/baz/"
  # ```
  def self.join(*parts) : self
    join parts
  end

  # Returns a new string formed by joining the strings using `Path::SEPARATOR`.
  #
  # ```
  # Path.join({"foo", "bar", "baz"})       # => "foo/bar/baz"
  # Path.join({"foo/", "/bar/", "/baz"})   # => "foo/bar/baz"
  # Path.join(["/foo/", "/bar/", "/baz/"]) # => "/foo/bar/baz/"
  # ```
  def self.join(parts : Array | Tuple) : self
    root = parts.first
    rest = parts.to_a[1..-1]
    new(root).join(rest)
  end

  # Returns a new string formed by joining the strings using `Path::SEPARATOR`.
  #
  # ```
  # Path.new("foo").join("bar", "baz")       # => "foo/bar/baz"
  # Path.new("foo/").join("/bar/", "/baz")   # => "foo/bar/baz"
  # Path.new("/foo/").join("/bar/", "/baz/") # => "/foo/bar/baz/"
  # ```
  def join(*parts) : self
    join parts
  end

  # Returns a new string formed by joining the strings using `Path::SEPARATOR`.
  #
  # ```
  # Path.new("foo").join({"bar", "baz"})       # => "foo/bar/baz"
  # Path.new("foo/").join({"/bar/", "/baz"})   # => "foo/bar/baz"
  # Path.new("/foo/").join(["/bar/", "/baz/"]) # => "/foo/bar/baz/"
  # ```
  def join(parts : Array(Path)) : self
    parts = [self] + parts
    str = String.build do |str|
      parts.each_with_index do |part, index|
        part_value = part.value
        part_value.check_no_null_byte

        str << SEPARATOR if index > 0

        byte_start = 0
        byte_count = part_value.bytesize

        if index > 0 && part_value.starts_with?(SEPARATOR)
          byte_start += 1
          byte_count -= 1
        end

        if index != parts.size - 1 && part_value.ends_with?(SEPARATOR)
          byte_count -= 1
        end

        str.write part_value.unsafe_byte_slice(byte_start, byte_count)
      end
    end

    self.class.new(str)
  end

  def join(parts : Array | Tuple) : self
    join(parts.to_a.map { |p| Path.new(p) })
  end

  def /(other)
    join([other])
  end

  def +(other)
    join([other])
  end

  protected def value
    @path
  end
end
