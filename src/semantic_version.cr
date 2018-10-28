# Conforms to Semantic Versioning 2.0.0
# See [https://semver.org/](https://semver.org/) for more information.
class SemanticVersion
  include Comparable(self)

  # The major version of this semantic version
  getter major : Int32

  # The minor version of this semantic version
  getter minor : Int32

  # The patch version of this semantic version
  getter patch : Int32

  # The build number of this semantic version
  getter build : String?

  # The pre-release metadata of this semantic version
  getter prerelease : Prerelease

  # Parses a `SemanticVersion` from the given semantic version string
  #
  # ```
  # require "semantic_version"
  #
  # semver = SemanticVersion.parse("2.61.4")
  # semver # => #<SemanticVersion:0x55b3667c9e70 @major=2, @minor=61, @patch=4, ... >
  # ```
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

  # Create a new `SemanticVersion` instance with the given major, minor, and patch versions
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

  # Returns the string representation of this semantic version
  #
  # ```
  # semver = SemanticVersion.parse("0.27.1")
  # semver.to_s # => "0.27.1"
  # ```
  def to_s(io : IO)
    io << major << '.' << minor << '.' << patch
    unless prerelease.identifiers.empty?
      io << '-'
      prerelease.to_s io
    end
    if build
      io << '+' << build
    end
  end

  # :nodoc:
  def <=>(other : self) : Int32
    r = major <=> other.major
    return r unless r.zero?
    r = minor <=> other.minor
    return r unless r.zero?
    r = patch <=> other.patch
    return r unless r.zero?

    pre1 = prerelease
    pre2 = other.prerelease

    prerelease <=> other.prerelease
  end

  # Contains additional pre-release metadata related to this semantic version
  struct Prerelease
    # Parses a `Prerelease` from the given pre-release metadata string
    #
    # ```
    # require "semantic_version"
    #
    # prerelease = SemanticVersion::Prerelease.parse("rc.1.3")
    # prerelease # => SemanticVersion::Prerelease(@identifiers=["rc", 1, 3])
    # ```
    def self.parse(str : String) : self
      identifiers = [] of String | Int32
      str.split('.').each do |val|
        if val.match /^\d+$/
          identifiers << val.to_i32
        else
          identifiers << val
        end
      end
      Prerelease.new identifiers
    end

    # Array of identifiers that make up the pre-release metadata
    getter identifiers : Array(String | Int32)

    # Create a new `Prerelease` instance with supplied array of identifiers
    def initialize(@identifiers : Array(String | Int32) = [] of String | Int32)
    end

    # Returns the string representation of this semantic version's pre-release metadata
    #
    # ```
    # require "semantic_version"
    #
    # semver = SemanticVersion.parse("0.27.1-rc.1")
    # semver.prerelease.to_s # => "rc.1"
    # ```
    def to_s(io : IO)
      identifiers.join(".", io)
    end

    # :nodoc:
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
        return 1 if i >= other.identifiers.size # larger = higher precedence

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
