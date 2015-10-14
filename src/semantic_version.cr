# Conforms to Semantic Versioning 2.0.0
# See http://semver.org/ for more information.
class SemanticVersion
  include Comparable(self)

  getter major, minor, patch, prerelease, build

  def self.parse str : String
    m = str.match /^(\d+)\.(\d+)\.(\d+)(-([\w\.]+))?(\+(\w+))??$/
    if m
      major = m[1].to_i
      minor = m[2].to_i
      patch = m[3].to_i
      prerelease = m[5]?
      build = m[7]?
      new major, minor, patch, prerelease, build
    else
      raise ArgumentError.new("not a semantic version: #{str.inspect}")
    end
  end

  def initialize @major : Int, @minor : Int, @patch : Int, prerelease = nil: String | Prerelease | Nil, @build = nil : String?
    @prerelease = case prerelease
    when Prerelease
      prerelease
    when String
      Prerelease.parse prerelease
    when nil
      Prerelease.new
    else
      raise ArgumentError.new("invalid prerelease #{prerelease.inspect}")
    end
  end

  def to_s io : IO
    io << major << "." << minor << "." << patch
    unless prerelease.empty?
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

  class Prerelease < Array(String | Int32)
    def self.parse str : String
      pre = Prerelease.new
      str.split(".").each do |val|
        if val.match /^\d+$/
          pre << val.to_i32
        else
          pre << val
        end
      end
      pre
    end

    def to_s io: IO
      each_with_index do |s, i|
        io << "." if i > 0
        io << s
      end
    end

    def <=>(other : self ) : Int32
      if empty?
        if other.empty?
          # continue
        else
          return 1
        end
      elsif other.empty?
        return -1
      else
        # continue
      end

      each_with_index do |item, i|
        return 1 if i >= other.size # larger = higher precedenc

        oitem = other[i]
        r = case item
        when Int32
          case oitem
          when Int32
            item <=> oitem
          when String # numeric identifiers have lower precedence than string
            -1
          else
            raise "COMPILER BUG: unknown type #{item.inspect} #{item.class}"
          end
        when String
          case oitem
          when Int32 # numeric identifiers have lower precedence than string
            1
          when String
            item <=> oitem
          else
            raise "COMPILER BUG: unknown type #{item.inspect} #{item.class}"
          end
        else
          raise "COMPILER BUG: unknown type #{item.inspect} #{item.class}"
        end

        return r if r != 0
      end

      return -1 if size != other.size # larger = higher precedence
      0
    end
  end
end
