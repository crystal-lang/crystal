# The `SoftwareVersion` type represents a version number.
#
# An instance can be created from a version string which consists of a series of
# segments separated by periods. Each segment contains one ore more alphanumerical
# ASCII characters. The first segment is expected to contain only digits.
#
# If the string contains a dash (`-`) or a letter, it is considered a
# pre-release.
#
# Optional version metadata may be attached and is separated by a plus character (`+`).
# All content following a `+` is considered metadata.
#
# This format is described by the regular expression:
# `/[0-9]+(?>\.[0-9a-zA-Z]+)*(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-.]+)?/`
#
# This implementation is compatible with popular versioning schemes such as
# [`SemVer`](https://semver.org/) and [`CalVer`](https://calver.org/) but
# doesn't enforce any particular one.
#
# It behaves mostly equivalent to [`Gem::Version`](http://docs.seattlerb.org/rubygems/Gem/Version.html)
# from `rubygems`.
#
# ## Sort order
# This wrapper type is mostly important for properly sorting version numbers,
# because generic lexical sorting doesn't work: For instance, `3.10` is supposed
# to be greater than `3.2`.
#
# Every set of consecutive digits anywhere in the string are interpreted as a
# decimal number and numerically sorted. Letters are lexically sorted.
# Periods (and dash) delimit numbers but don't affect sort order by themselves.
# Thus `1.0a` is considered equal to `1.0.a`.
#
# Pre-releases are sorted lower than the corresponding release version which
# includes the characters up to the first dash or letter. For instance `1.0-b`
# compares lower than `1.0` but greater than `1.0-a`.
struct SoftwareVersion
  include Comparable(self)

  # :nodoc:
  VERSION_PATTERN = /[0-9]+(?>\.[0-9a-zA-Z]+)*(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-.]+)?/
  # :nodoc:
  ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})\s*\z/

  @version : String

  # Returns `true` if *string* is a valid version format.
  def self.valid?(string : String) : Bool
    !ANCHORED_VERSION_PATTERN.match(string).nil?
  end

  # Constructs an instance from *string*.
  protected def initialize(@version : String)
  end

  # Parses an instance from a string.
  #
  # A version string is a series of digits or ASCII letters separated by dots.
  #
  # Returns `nil` if *string* describes an invalid version.
  def self.parse?(string : String) : self?
    # If string is an empty string convert it to 0
    string = "0" if string.blank?

    return unless valid?(string)

    new(string.strip)
  end

  # Parses an instance from a string.
  #
  # A version string is a series of digits or ASCII letters separated by dots.
  #
  # Raises `ArgumentError` if *string* describes an invalid version.
  def self.parse(string : String) : self
    parse?(string) || raise ArgumentError.new("Malformed version string #{string.inspect}")
  end

  # Constructs a `Version` from the string representation of *version* number.
  def self.new(version : Number) : self
    new(version.to_s)
  end

  # Constructs an instance from arguments.
  #
  # ```
  # require "software_version"
  #
  # SoftwareVersion.new(1, 0).to_s                                           # => "1.0"
  # SoftwareVersion.new(1, 0, 0, prerelease: "rc1", metadata: "build8").to_s # => "1.0.0-rc1+build8"
  # ```
  def self.new(major : Int, minor : Int? = nil, patch : Int? = nil, *, prerelease : String? = nil, metadata : String? = nil)
    string = String.build do |io|
      io << major
      io << '.' << minor if minor
      io << '.' << patch if patch
      io << '-' << prerelease if prerelease
      io << '+' << metadata if metadata
    end
    new string
  end

  # Appends the string representation of this version to *io*.
  def to_s(io : IO) : Nil
    @version.to_s(io)
  end

  # Returns the string representation of this version.
  def to_s : String
    @version
  end

  # Returns `true` if this version is a pre-release version.
  #
  # A version is considered pre-release if it contains a letter or a dash (`-`).
  #
  # ```
  # require "software_version"
  #
  # SoftwareVersion.parse("1.0.0").prerelease?     # => false
  # SoftwareVersion.parse("1.0.0-dev").prerelease? # => true
  # SoftwareVersion.parse("1.0.0-1").prerelease?   # => true
  # SoftwareVersion.parse("1.0.0a1").prerelease?   # => true
  # ```
  def prerelease? : Bool
    @version.each_char do |char|
      if char.ascii_letter? || char == '-'
        return true
      elsif char == '+'
        # the following chars are metadata
        return false
      end
    end

    false
  end

  # Returns the metadata attached to this version or `nil` if no metadata available.
  #
  # ```
  # require "software_version"
  #
  # SoftwareVersion.parse("1.0.0").metadata            # => nil
  # SoftwareVersion.parse("1.0.0-rc1").metadata        # => nil
  # SoftwareVersion.parse("1.0.0+build1").metadata     # => "build1"
  # SoftwareVersion.parse("1.0.0-rc1+build1").metadata # => "build1"
  # ```
  def metadata : String?
    if index = @version.byte_index('+'.ord)
      @version.byte_slice(index + 1, @version.bytesize - index - 1)
    end
  end

  # Returns a `SoftwareVersion` representing the corresponding release version of
  # `self`.
  #
  # If this version is a pre-release a new instance will be created
  # with the same version string before the first letter or dash.
  #
  # Version metadata will be stripped.
  #
  # ```
  # require "software_version"
  #
  # SoftwareVersion.parse("1.0").release        # => SoftwareVersion.parse("1.0")
  # SoftwareVersion.parse("1.0-dev").release    # => SoftwareVersion.parse("1.0")
  # SoftwareVersion.parse("1.0-1").release      # => SoftwareVersion.parse("1.0")
  # SoftwareVersion.parse("1.0a1").release      # => SoftwareVersion.parse("1.0")
  # SoftwareVersion.parse("1.0+b1").release     # => SoftwareVersion.parse("1.0")
  # SoftwareVersion.parse("1.0-rc1+b1").release # => SoftwareVersion.parse("1.0")
  # ```
  def release : self
    @version.each_char_with_index do |char, index|
      if char.ascii_letter? || char == '-' || char == '+'
        return self.class.new(@version.byte_slice(0, index))
      end
    end

    self
  end

  # Compares this version with *other* returning `-1`, `0`, or `1` depending on whether
  # *other*'s version is lower, equal or greater than `self`.
  def <=>(other : self) : Int
    lstring = @version
    rstring = other.@version
    lindex = 0
    rindex = 0

    while true
      lchar = lstring.byte_at?(lindex).try &.chr
      rchar = rstring.byte_at?(rindex).try &.chr

      # Both strings have been entirely consumed, they're identical
      return 0 if lchar.nil? && rchar.nil?

      ldelimiter = {'.', '-'}.includes?(lchar)
      rdelimiter = {'.', '-'}.includes?(rchar)

      # Skip delimiters
      lindex += 1 if ldelimiter
      rindex += 1 if rdelimiter
      next if ldelimiter || rdelimiter

      # If one string is consumed, the other is either ranked higher (char is a digit)
      # or lower (char is letter, making it a pre-release tag).
      if lchar.nil?
        return rchar.not_nil!.ascii_letter? ? 1 : -1
      elsif rchar.nil?
        return lchar.ascii_letter? ? -1 : 1
      end

      # Try to consume consecutive digits into a number
      lnumber, new_lindex = consume_number(lstring, lindex)
      rnumber, new_rindex = consume_number(rstring, rindex)

      # Proceed depending on where a number was found on each string
      case {new_lindex, new_rindex}
      when {lindex, rindex}
        # Both strings have a letter at current position.
        # They are compared (lexical) and the algorithm only continues if they
        # are equal.
        ret = lchar <=> rchar
        return ret unless ret == 0

        lindex += 1
        rindex += 1
      when {_, rindex}
        # Left hand side has a number, right hand side a letter (and thus a pre-release tag)
        return -1
      when {lindex, _}
        # Right hand side has a number, left hand side a letter (and thus a pre-release tag)
        return 1
      else
        # Both strings have numbers at current position.
        # They are compared (numerical) and the algorithm only continues if they
        # are equal.
        ret = lnumber <=> rnumber
        return ret unless ret == 0

        # Move to the next position in both strings
        lindex = new_lindex
        rindex = new_rindex
      end
    end
  end

  # Helper method to read a sequence of digits from *string* starting at
  # position *index* into an integer number.
  # It returns the consumed number and index position.
  private def consume_number(string : String, index : Int32)
    number = 0
    while (byte = string.byte_at?(index)) && byte.chr.ascii_number?
      number *= 10
      number += byte
      index += 1
    end
    {number, index}
  end

  # Implements the pessimistic version constraint `~>`.
  #
  # A version matches *constraint* if is equal to the constraint comparing up
  # to the constraint's second-to-last segment and the following segment is
  # greater than the constraint's.
  #
  # ```
  # require "software_version"
  #
  # SoftwareVersion.parse("1.0.0").matches_pessimistic_version_constraint?("1.0.0") # => true
  # SoftwareVersion.parse("1.0.1").matches_pessimistic_version_constraint?("1.0.0") # => true
  # SoftwareVersion.parse("1.1.0").matches_pessimistic_version_constraint?("1.0.0") # => false
  # SoftwareVersion.parse("1.1.0").matches_pessimistic_version_constraint?("1.0")   # => true
  # SoftwareVersion.parse("2.0.0").matches_pessimistic_version_constraint?("1.0")   # => false
  # ```
  def matches_pessimistic_version_constraint?(constraint : String) : Bool
    constraint = self.class.parse(constraint).release.to_s

    if last_period_index = constraint.rindex('.')
      constraint_lead = constraint.[0...last_period_index]
    else
      constraint_lead = constraint
    end
    last_period_index = constraint_lead.bytesize

    # Compare the leading part of the constraint up until the last period.
    # If it doesn't match, the constraint is not fulfilled.
    return false unless @version.starts_with?(constraint_lead)

    # The character following the constraint lead can't be a number, otherwise
    # `0.10` would match `0.1` because it starts with the same three characters
    next_char = @version.byte_at?(last_period_index).try &.chr
    return true unless next_char
    return false if next_char.ascii_number?

    # We've established that constraint is met up until the second-to-last
    # segment.
    # Now we only need to ensure that the last segment is actually bigger than
    # the constraint so that `0.1` doesn't match `~> 0.2`.
    # self >= constraint
    constraint_number, _ = consume_number(constraint, last_period_index + 1)
    own_number, _ = consume_number(@version, last_period_index + 1)

    own_number >= constraint_number
  end

  # Custom hash implementation which produces the same hash for `a` and `b` when `a <=> b == 0`
  def hash(hasher)
    string = @version
    index = 0

    while byte = string.byte_at?(index)
      if {'.'.ord, '-'.ord}.includes?(byte)
        index += 1
        next
      end

      number, new_index = consume_number(string, index)

      if new_index != index
        hasher.int(number)
        index = new_index
      else
        hasher.int(byte)
      end
      index += 1
    end

    hasher
  end
end
