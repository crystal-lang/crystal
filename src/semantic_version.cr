# Conforms to Semantic Versioning 2.0.0
# See http://semver.org/ for more information.
class SemanticVersion
  include Comparable(self)

  getter major : Int32
  getter minor : Int32
  getter patch : Int32
  getter build : String?
  getter prerelease : Prerelease

  def self.parse(str : String) : self
    m = str.match /^(\d+)\.(\d+)\.(\d+)(-([\w\.]+))?(\+(\w+))??$/
    if m
      major = m[1].to_i
      minor = m[2].to_i
      patch = m[3].to_i
      prerelease = m[5]?
      build = m[7]?
      new major, minor, patch, prerelease, build
    else
      raise ArgumentError.new("Not a semantic version: #{str.inspect}")
    end
  end

  def initialize(@major : Int, @minor : Int, @patch : Int, prerelease : String | Prerelease | Nil = nil, @build : String? = nil)
    @prerelease = case prerelease
                  when Prerelease
                    prerelease
                  when String
                    Prerelease.parse prerelease
                  when nil
                    Prerelease.new
                  else
                    raise ArgumentError.new("Invalid prerelease #{prerelease.inspect}")
                  end
  end

  def to_s(io : IO)
    io << major << "." << minor << "." << patch
    unless prerelease.identifiers.empty?
      io << "-"
      prerelease.to_s io
    end
    if build
      io << "+" << build
    end
  end

  def <=>(other : self) : Int32
    r = major <=> other.major
    return r if r != 0
    r = minor <=> other.minor
    return r if r != 0
    r = patch <=> other.patch
    return r if r != 0

    pre1 = prerelease
    pre2 = other.prerelease

    prerelease <=> other.prerelease
  end

  struct Prerelease
    def self.parse(str : String) : self
      identifiers = [] of String | Int32
      str.split(".").each do |val|
        if val.match /^\d+$/
          identifiers << val.to_i32
        else
          identifiers << val
        end
      end
      Prerelease.new identifiers
    end

    getter identifiers : Array(String | Int32)

    def initialize(@identifiers : Array(String | Int32) = [] of String | Int32)
    end

    def to_s(io : IO)
      identifiers.each_with_index do |s, i|
        io << "." if i > 0
        io << s
      end
    end

    def <=>(other : self) : Int32
      if identifiers.empty?
        if other.identifiers.empty?
          return 0
        else
          return 1
        end
      elsif other.identifiers.empty?
        return -1
      else
        # continue
      end

      identifiers.each_with_index do |item, i|
        return 1 if i >= other.identifiers.size # larger = higher precedenc

        oitem = other.identifiers[i]
        r = compare item, oitem
        return r if r != 0
      end

      return -1 if identifiers.size != other.identifiers.size # larger = higher precedence
      0
    end

    private def compare(x : Int32, y : String)
      -1
    end

    private def compare(x : String, y : Int32)
      1
    end

    private def compare(x : Int32, y : Int32)
      x <=> y
    end

    private def compare(x : String, y : String)
      x <=> y
    end
  end
end
