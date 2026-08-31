require "./regex/engine"
require "./regex/match_data"

# A `Regex` represents a regular expression, a pattern that describes the
# contents of strings. A `Regex` can determine whether or not a string matches
# its description, and extract the parts of the string that match.
#
# A `Regex` can be created using the literal syntax, in which it is delimited by
# forward slashes (`/`):
#
# ```
# /hay/ =~ "haystack"   # => 0
# /y/.match("haystack") # => Regex::MatchData("y")
# ```
#
# See [`Regex` literals](https://crystal-lang.org/reference/syntax_and_semantics/literals/regex.html) in the language reference.
#
# Interpolation works in regular expression literals just as it does in string
# literals. Be aware that using this feature will cause an exception to be
# raised at runtime, if the resulting string would not be a valid regular
# expression.
#
# ```
# x = "a"
# /#{x}/.match("asdf") # => Regex::MatchData("a")
# x = "("
# /#{x}/ # raises ArgumentError
# ```
#
# When we check to see if a particular regular expression describes a string,
# we can say that we are performing a match or matching one against the other.
# If we find that a regular expression does describe a string, we say that it
# matches, and we can refer to a part of the string that was described as
# a match.
#
# Here `"haystack"` does not contain the pattern `/needle/`, so it doesn't match:
#
# ```
# /needle/.match("haystack") # => nil
# ```
#
# Here `"haystack"` contains the pattern `/hay/`, so it matches:
#
# ```
# /hay/.match("haystack") # => Regex::MatchData("hay")
# ```
#
# Regex methods that perform a match usually return a truthy value if there was
# a match and `nil` if there was no match. After performing a match, the
# special variable `$~` will be an instance of `Regex::MatchData` if it matched, `nil`
# otherwise.
#
# When matching a regular expression using `=~` (either `String#=~` or
# `Regex#=~`), the returned value will be the index of the first match in the
# string if the expression matched, `nil` otherwise.
#
# ```
# /stack/ =~ "haystack"  # => 3
# "haystack" =~ /stack/  # => 3
# $~                     # => Regex::MatchData("stack")
# /needle/ =~ "haystack" # => nil
# "haystack" =~ /needle/ # => nil
# $~                     # raises Exception
# ```
#
# When matching a regular expression using `#match` (either `String#match` or
# `Regex#match`), the returned value will be a `Regex::MatchData` if the expression
# matched, `nil` otherwise.
#
# ```
# /hay/.match("haystack")    # => Regex::MatchData("hay")
# "haystack".match(/hay/)    # => Regex::MatchData("hay")
# $~                         # => Regex::MatchData("hay")
# /needle/.match("haystack") # => nil
# "haystack".match(/needle/) # => nil
# $~                         # raises Exception
# ```
#
# [Regular expressions](https://en.wikipedia.org/wiki/Regular_expression)
# have their own language for describing strings.
#
# Many programming languages and tools implement their own regular expression
# language, but Crystal uses [PCRE2](http://www.pcre.org/), a popular C library, with
# [JIT compilation](http://www.pcre.org/current/doc/html/pcre2jit.html) enabled
# for providing regular expressions. Here give a brief summary of the most
# basic features of regular expressions - grouping, repetition, and
# alternation - but the feature set of PCRE2 extends far beyond these, and we
# don't attempt to describe it in full here. For more information, refer to
# the PCRE2 documentation, especially the
# [full pattern syntax](http://www.pcre.org/current/doc/html/pcre2pattern.html)
# or
# [syntax quick reference](http://www.pcre.org/current/doc/html/pcre2syntax.html).
#
# NOTE: Prior to Crystal 1.8 the compiler expected regex literals to follow the
# original [PCRE pattern syntax](https://www.pcre.org/original/doc/html/pcrepattern.html).
# The following summary applies to both PCRE and PCRE2.
#
# The regular expression language can be used to match much more than just the
# static substrings in the above examples. Certain characters, called
# [metacharacters](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC4),
# are given special treatment in regular expressions, and can be used to
# describe more complex patterns. To match metacharacters literally in a
# regular expression, they must be escaped by being preceded with a backslash
# (`\`). `escape` will do this automatically for a given String.
#
# A group of characters (often called a capture group or
# [subpattern](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC14))
# can be identified by enclosing it in parentheses (`()`). The contents of
# each capture group can be extracted on a successful match:
#
# ```
# /a(sd)f/.match("_asdf_")                     # => Regex::MatchData("asdf" 1:"sd")
# /a(sd)f/.match("_asdf_").try &.[1]           # => "sd"
# /a(?<grp>sd)f/.match("_asdf_")               # => Regex::MatchData("asdf" grp:"sd")
# /a(?<grp>sd)f/.match("_asdf_").try &.["grp"] # => "sd"
# ```
#
# Capture groups are indexed starting from 1. Methods that accept a capture
# group index will usually also accept 0 to refer to the full match. Capture
# groups can also be given names, using the `(?&lt;name&gt;...)` syntax, as in the
# previous example.
#
# Following a match, the special variables $N (e.g., $1, $2, $3, ...) can be used
# to access a capture group. Trying to access an invalid capture group will raise an
# exception. Note that it is possible to have a successful match with a nil capture:
#
# ```
# /(spice)(s)?/.match("spice") # => Regex::MatchData("spice" 1:"spice" 2:nil)
# $1                           # => "spice"
# $2                           # => raises Exception
# ```
#
# This can be mitigated by using the nilable version of the above: $N?,
# (e.g., $1? $2?, $3?, ...). Changing the above to use `$2?` instead of `$2`
# would return `nil`. `$2?.nil?` would return `true`.
#
# A character or group can be
# [repeated](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC17)
# or made optional using an asterisk (`*` - zero or more), a plus sign
# (`+` - one or more), integer bounds in curly braces
# (`{n,m}`) (at least `n`, no more than `m`), or a question mark
# (`?`) (zero or one).
#
# ```
# /fo*/.match("_f_")         # => Regex::MatchData("f")
# /fo+/.match("_f_")         # => nil
# /fo*/.match("_foo_")       # => Regex::MatchData("foo")
# /fo{3,}/.match("_foo_")    # => nil
# /fo{1,3}/.match("_foo_")   # => Regex::MatchData("foo")
# /fo*/.match("_foo_")       # => Regex::MatchData("foo")
# /fo*/.match("_foooooooo_") # => Regex::MatchData("foooooooo")
# /fo{,3}/.match("_foooo_")  # => nil
# /f(op)*/.match("fopopo")   # => Regex::MatchData("fopop" 1:"op")
# /foo?bar/.match("foobar")  # => Regex::MatchData("foobar")
# /foo?bar/.match("fobar")   # => Regex::MatchData("fobar")
# ```
#
# Alternatives can be separated using a
# [vertical bar](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC12)
# (`|`). Any single character can be represented by
# [dot](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC7)
# (`.`). When matching only one character, specific
# alternatives can be expressed as a
# [character class](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC9),
# enclosed in square brackets (`[]`):
#
# ```
# /foo|bar/.match("foo")     # => Regex::MatchData("foo")
# /foo|bar/.match("bar")     # => Regex::MatchData("bar")
# /_(x|y)_/.match("_x_")     # => Regex::MatchData("_x_" 1:"x")
# /_(x|y)_/.match("_y_")     # => Regex::MatchData("_y_" 1:"y")
# /_(x|y)_/.match("_(x|y)_") # => nil
# /_(x|y)_/.match("_(x|y)_") # => nil
# /_._/.match("_x_")         # => Regex::MatchData("_x_")
# /_[xyz]_/.match("_x_")     # => Regex::MatchData("_x_")
# /_[a-z]_/.match("_x_")     # => Regex::MatchData("_x_")
# /_[^a-z]_/.match("_x_")    # => nil
# /_[^a-wy-z]_/.match("_x_") # => Regex::MatchData("_x_")
# ```
#
# Regular expressions can be defined with these 3
# [optional flags](http://www.pcre.org/current/doc/html/pcre2pattern.html#SEC13):
#
# * `i`: ignore case (`Regex::Options::IGNORE_CASE`)
# * `m`: multiline (`Regex::Options::MULTILINE`)
# * `x`: extended (`Regex::Options::EXTENDED`)
#
# ```
# /asdf/ =~ "ASDF"    # => nil
# /asdf/i =~ "ASDF"   # => 0
# /^z/i =~ "ASDF\nZ"  # => nil
# /^z/im =~ "ASDF\nZ" # => 5
# ```
#
# PCRE2 supports other encodings, but Crystal strings are UTF-8 only, so Crystal
# regular expressions are also UTF-8 only (by default).
# Crystal strings are expected to contain only valid UTF-8 encodings, but that's
# not guaranteed. There's a chance that a string *can* contain invalid bytes.
# Especially data read from external sources must not be trusted to be valid encoding.
# The regex engine demands valid UTF-8, so it checks the encoding for every
# match. This can be unnecessary if the string is already validated (for example
# via `String#valid_encoding?` or because it has already been used in a previous
# regex match).
# If that's the case, it's profitable to skip UTF-8 validation via `MatchOptions::NO_UTF_CHECK`
# (or `CompileOptions::NO_UTF_CHECK` for the pattern).
#
# PCRE2 optionally permits named capture groups (named subpatterns) to not be
# unique. Crystal exposes the name table of a `Regex` as a
# `Hash` of `String` => `Int32`, and therefore requires named capture groups to have
# unique names within a single `Regex`.
class Regex
  include Regex::Engine

  class Error < Exception
  end

  # List of metacharacters that need to be escaped.
  #
  # See `Regex.needs_escape?` and `Regex.escape`.
  SPECIAL_CHARACTERS = {
    ' ', '.', '\\', '+', '*', '?', '[',
    '^', ']', '$', '(', ')', '{', '}',
    '=', '!', '<', '>', '|', ':', '-',
  }

  # Represents compile options passed to `Regex.new`.
  #
  # This type is intended to be renamed to `CompileOptions`. Please use that
  # name.
  @[Flags]
  enum Options : UInt64
    # Case insensitive match.
    IGNORE_CASE = 0x0000_0001

    # PCRE native `PCRE_MULTILINE` flag is `2`, and `PCRE_DOTALL` is `4`
    # - `PCRE_DOTALL` changes the "`.`" meaning
    # - `PCRE_MULTILINE` changes "`^`" and "`$`" meanings
    #
    # Crystal modifies this meaning to have essentially one unique "`m`"
    # flag that activates both behaviours, so here we do the same by
    # mapping `MULTILINE` to `PCRE_MULTILINE | PCRE_DOTALL`.
    # The same applies for PCRE2 except that the native values are 0x200 and 0x400.
    #
    # For the behaviour of `PCRE_MULTILINE` use `MULTILINE_ONLY`.

    # Multiline matching.
    #
    # Equivalent to `MULTILINE | DOTALL` in PCRE and PCRE2.
    MULTILINE = 0x0000_0006

    # Equivalent to `MULTILINE` in PCRE and PCRE2.
    MULTILINE_ONLY = 0x0000_0004

    DOTALL = 0x0000_0002

    # Ignore white space and `#` comments.
    EXTENDED = 0x0000_0008

    # Force pattern anchoring at the start of the subject.
    ANCHORED = 0x0000_0010

    DOLLAR_ENDONLY = 0x0000_0020
    FIRSTLINE      = 0x0004_0000

    # :nodoc:
    UTF_8 = 0x0000_0800
    # :nodoc:
    NO_UTF8_CHECK = 0x0000_2000
    # :nodoc:
    DUPNAMES = 0x0008_0000
    # :nodoc:
    UCP = 0x2000_0000

    # Force pattern anchoring at the end of the subject.
    #
    # Unsupported with PCRE.
    ENDANCHORED = 0x8000_0000

    # Do not check the pattern for valid UTF encoding.
    #
    # This option is potentially dangerous and must only be used when the
    # pattern is guaranteed to be valid (e.g. `String#valid_encoding?`).
    # Failing to do so can lead to undefined behaviour in the regex library
    # and may crash the entire process.
    #
    # NOTE: `String` is *supposed* to be valid UTF-8, but this is not guaranteed or
    # enforced. Especially data originating from external sources should not be
    # trusted.
    #
    # UTF validation is comparatively expensive, so skipping it can produce a
    # significant performance improvement.
    #
    # ```
    # pattern = "fo+"
    # if pattern.valid_encoding?
    #   regex = Regex.new(pattern, options: Regex::CompileOptions::NO_UTF_CHECK)
    #   regex.match(foo)
    # else
    #   raise "Invalid UTF in regex pattern"
    # end
    # ```
    #
    # The standard library implicitly applies this option when it can be sure
    # about the patterns's validity (e.g. on repeated matches in `String#gsub`).
    NO_UTF_CHECK = NO_UTF8_CHECK

    # Enable matching against subjects containing invalid UTF bytes.
    # Invalid bytes never match anything. The entire subject string is
    # effectively split into segments of valid UTF.
    #
    # Read more in the [PCRE2 documentation](https://www.pcre.org/current/doc/html/pcre2unicode.html#matchinvalid).
    #
    # When this option is set, `MatchOptions::NO_UTF_CHECK` is ignored at match time.
    #
    # Unsupported with PCRE.
    #
    # NOTE: This option was introduced in PCRE2 10.34 but a bug that can lead to an
    # infinite loop is only fixed in 10.36 (https://github.com/PCRE2Project/pcre2/commit/e0c6029a62db9c2161941ecdf459205382d4d379).
    MATCH_INVALID_UTF = 0x1_0000_0000
  end

  # Represents compile options passed to `Regex.new`.
  #
  # This alias is supposed to replace `Options`.
  alias CompileOptions = Options

  # Returns `true` if the regex engine supports all *options* flags when compiling a pattern.
  def self.supports_compile_options?(options : CompileOptions) : Bool
    options.each do |flag|
      return false unless Engine.supports_compile_flag?(flag)
    end
    true
  end

  # Represents options passed to regex match methods such as `Regex#match`.
  @[Flags]
  enum MatchOptions
    # Force pattern anchoring at the start of the subject.
    ANCHORED

    # Force pattern anchoring at the end of the subject.
    #
    # Unsupported with PCRE.
    ENDANCHORED

    # Disable JIT engine.
    #
    # Unsupported with PCRE.
    NO_JIT

    # Do not check subject for valid UTF encoding.
    #
    # This option is potentially dangerous and must only be used when the
    # subject is guaranteed to be valid (e.g. `String#valid_encoding?`).
    # Failing to do so can lead to undefined behaviour in the regex library
    # and may crash the entire process.
    #
    # NOTE: `String` is *supposed* to be valid UTF-8, but this is not guaranteed or
    # enforced. Especially data originating from external sources should not be
    # trusted.
    #
    # UTF validation is comparatively expensive, so skipping it can produce a
    # significant performance improvement.
    #
    # ```
    # subject = "foo"
    # if subject.valid_encoding?
    #   /foo/.match(subject, options: Regex::MatchOptions::NO_UTF_CHECK)
    # else
    #   raise "Invalid UTF in regex subject"
    # end
    # ```
    #
    # A good use case is when the same subject is matched multiple times, UTF
    # validation only needs to happen once.
    #
    # This option has no effect if the pattern was compiled with
    # `CompileOptions::MATCH_INVALID_UTF` when using PCRE2 10.34+.
    NO_UTF_CHECK
  end

  # Returns `true` if the regex engine supports all *options* flags when matching a pattern.
  def self.supports_match_options?(options : MatchOptions) : Bool
    options.each do |flag|
      return false unless Engine.supports_match_flag?(flag)
    end
    true
  end

  # Returns a `Regex::CompileOptions` representing the optional flags applied to this `Regex`.
  #
  # ```
  # /ab+c/ix.options      # => Regex::CompileOptions::IGNORE_CASE | Regex::CompileOptions::EXTENDED
  # /ab+c/ix.options.to_s # => "IGNORE_CASE | EXTENDED"
  # ```
  getter options : Options

  # Returns the original `String` representation of the `Regex` pattern.
  #
  # ```
  # /ab+c/x.source # => "ab+c"
  # ```
  getter source : String

  # Creates a new `Regex` out of the given source `String`.
  #
  # ```
  # Regex.new("^a-z+:\\s+\\w+")                          # => /^a-z+:\s+\w+/
  # Regex.new("cat", Regex::CompileOptions::IGNORE_CASE) # => /cat/i
  # options = Regex::CompileOptions::IGNORE_CASE | Regex::CompileOptions::EXTENDED
  # Regex.new("dog", options) # => /dog/ix
  # ```
  def self.new(source : String, options : Options = Options::None) : self
    new(_source: source, _options: options)
  end

  # Creates a new `Regex` instance from a literal consisting of a *pattern* and the named parameter modifiers.
  def self.literal(pattern : String, *, i : Bool = false, m : Bool = false, x : Bool = false) : self
    options = CompileOptions::None
    options |= :ignore_case if i
    options |= :multiline if m
    options |= :extended if x
    new(pattern, options: options)
  end

  # Determines Regex's source validity. If it is, `nil` is returned.
  # If it's not, a `String` containing the error message is returned.
  #
  # ```
  # Regex.error?("(foo|bar)") # => nil
  # Regex.error?("(foo|bar")  # => "missing ) at 8"
  # ```
  def self.error?(source : String) : String?
    Engine.error_impl(source)
  end

  # Returns `true` if *char* need to be escaped, `false` otherwise.
  #
  # ```
  # Regex.needs_escape?('*') # => true
  # Regex.needs_escape?('@') # => false
  # ```
  def self.needs_escape?(char : Char) : Bool
    SPECIAL_CHARACTERS.includes?(char)
  end

  # Returns `true` if *str* need to be escaped, `false` otherwise.
  #
  # ```
  # Regex.needs_escape?("10$") # => true
  # Regex.needs_escape?("foo") # => false
  # ```
  def self.needs_escape?(str : String) : Bool
    str.each_char { |char| return true if SPECIAL_CHARACTERS.includes?(char) }
    false
  end

  # Returns a `String` constructed by escaping any metacharacters in *str*.
  #
  # ```
  # string = Regex.escape("*?{}.") # => "\\*\\?\\{\\}\\."
  # /#{string}/                    # => /\*\?\{\}\./
  # ```
  def self.escape(str : String) : String
    String.build do |result|
      str.each_byte do |byte|
        {% begin %}
          case byte.unsafe_chr
          when {{ SPECIAL_CHARACTERS.splat }}
            result << '\\'
            result.write_byte byte
          else
            result.write_byte byte
          end
        {% end %}
      end
    end
  end

  # Union. Returns a `Regex` that matches any of *patterns*.
  #
  # All capture groups in the patterns after the first one will have their
  # indexes offset.
  #
  # ```
  # re = Regex.union([/skiing/i, "sledding"])
  # re.match("Skiing")   # => Regex::MatchData("Skiing")
  # re.match("sledding") # => Regex::MatchData("sledding")
  # re = Regex.union({/skiing/i, "sledding"})
  # re.match("Skiing")   # => Regex::MatchData("Skiing")
  # re.match("sledding") # => Regex::MatchData("sledding")
  # ```
  def self.union(patterns : Enumerable(Regex | String)) : self
    new patterns.map { |pattern| union_part pattern }.join('|')
  end

  # Union. Returns a `Regex` that matches any of *patterns*.
  #
  # All capture groups in the patterns after the first one will have their
  # indexes offset.
  #
  # ```
  # re = Regex.union(/skiing/i, "sledding")
  # re.match("Skiing")   # => Regex::MatchData("Skiing")
  # re.match("sledding") # => Regex::MatchData("sledding")
  # ```
  def self.union(*patterns : Regex | String) : self
    union patterns
  end

  private def self.union_part(pattern : Regex)
    pattern.to_s
  end

  private def self.union_part(pattern : String)
    escape pattern
  end

  # Union. Returns a `Regex` that matches either of the operands.
  #
  # All capture groups in the second operand will have their indexes
  # offset.
  #
  # ```
  # re = /skiing/i + /sledding/
  # re.match("Skiing")   # => Regex::MatchData("Skiing")
  # re.match("sledding") # => Regex::MatchData("sledding")
  # ```
  def +(other) : Regex
    Regex.union(self, other)
  end

  # Equality. Two regexes are equal if their sources and options are the same.
  #
  # ```
  # /abc/ == /abc/i  # => false
  # /abc/i == /ABC/i # => false
  # /abc/i == /abc/i # => true
  # ```
  def ==(other : Regex) : Bool
    source == other.source && options == other.options
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher = source.hash hasher
    hasher = options.hash hasher
    hasher
  end

  # Case equality. This is equivalent to `#match` or `#=~` but only returns
  # `true` or `false`. Used in `case` expressions. The special variable
  # `$~` will contain a `Regex::MatchData` if there was a match, `nil` otherwise.
  #
  # ```
  # a = "HELLO"
  # b = case a
  #     when /^[a-z]*$/
  #       "Lower case"
  #     when /^[A-Z]*$/
  #       "Upper case"
  #     else
  #       "Mixed case"
  #     end
  # b # => "Upper case"
  # ```
  def ===(other : String) : Bool
    match = match(other)
    $~ = match
    !match.nil?
  end

  # Match. Matches a regular expression against *other* and returns
  # the starting position of the match if *other* is a matching `String`,
  # otherwise `nil`. `$~` will contain a `Regex::MatchData` if there was a match,
  # `nil` otherwise.
  #
  # ```
  # /at/ =~ "input data" # => 7
  # /ax/ =~ "input data" # => nil
  # ```
  def =~(other : String) : Int32?
    match = self.match(other)
    $~ = match
    match.try &.begin(0)
  end

  # Match. When the argument is not a `String`, always returns `nil`.
  #
  # ```
  # /at/ =~ "input data" # => 7
  # /ax/ =~ "input data" # => nil
  # ```
  def =~(other) : Nil
    nil
  end

  # Prints to *io* an unambiguous string representation of this regular expression object.
  #
  # Uses the regex literal syntax with basic option flags if sufficient (i.e. no
  # other options than `IGNORE_CASE`, `MULTILINE`, or `EXTENDED` are set).
  # Otherwise the syntax presents a `Regex.new` call.
  # ```
  # /ab+c/ix.inspect                     # => "/ab+c/ix"
  # Regex.new("ab+c", :anchored).inspect # => Regex.new("ab+c", Regex::Options::ANCHORED)
  # ```
  def inspect(io : IO) : Nil
    if (options & ~CompileOptions[IGNORE_CASE, MULTILINE, EXTENDED]).none?
      inspect_literal(io)
    else
      inspect_extensive(io)
    end
  end

  # Convert to `String` in literal format. Returns the source as a `String` in
  # Regex literal format, delimited in forward slashes (`/`), with option flags
  # included.
  #
  # Only `IGNORE_CASE`, `MULTILINE`, and `EXTENDED` options can be represented.
  # Any other option value is ignored. Use `#inspect` instead for an unambiguous
  # and correct representation.
  #
  # ```
  # /ab+c/ix.inspect_literal                     # => "/ab+c/ix"
  # Regex.new("ab+c", :anchored).inspect_literal # => "/ab+c/"
  # ```
  private def inspect_literal(io : IO) : Nil
    io << '/'
    Regex.append_source(source, io)
    io << '/'
    io << 'i' if options.ignore_case?
    io << 'm' if options.multiline?
    io << 'x' if options.extended?
  end

  # Prints to *io* an extensive string representation of this regular expression object.
  # The result is unambiguous and mirrors a Crystal expression to recreate an equivalent
  # instance.
  #
  # ```
  # /ab+c/ix.inspect_literal                     # => Regex.new("ab+c", Regex::Options[IGNORE_CASE, EXTENDED])
  # Regex.new("ab+c", :anchored).inspect_literal # => Regex.new("ab+c", Regex::Options::ANCHORED)
  # ```
  private def inspect_extensive(io : IO) : Nil
    io << "Regex.new("
    source.inspect(io)
    io << ", "
    options.inspect(io)
    io << ")"
  end

  # Match at character index. Matches a regular expression against `String`
  # *str*. Starts at the character index given by *pos* if given, otherwise at
  # the start of *str*. Returns a `Regex::MatchData` if *str* matched, otherwise
  # `nil`. `$~` will contain the same value that was returned.
  #
  # ```
  # /(.)(.)(.)/.match("abc").try &.[2]   # => "b"
  # /(.)(.)/.match("abc", 1).try &.[2]   # => "c"
  # /(.)(.)/.match("クリスタル", 3).try &.[2] # => "ル"
  # ```
  def match(str : String, pos : Int32 = 0, options : Regex::MatchOptions = :none) : MatchData?
    if byte_index = str.char_index_to_byte_index(pos)
      $~ = match_at_byte_index(str, byte_index, options)
    else
      $~ = nil
    end
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def match(str, pos = 0, *, options) : MatchData?
    if byte_index = str.char_index_to_byte_index(pos)
      $~ = match_at_byte_index(str, byte_index, options)
    else
      $~ = nil
    end
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def match(str, pos, _options) : MatchData?
    match(str, pos, options: _options)
  end

  # Matches a regular expression against *str*. This starts at the character
  # index *pos* if given, otherwise at the start of *str*. Returns a `Regex::MatchData`
  # if *str* matched, otherwise raises `Regex::Error`. `$~` will contain the same value
  # if matched.
  #
  # ```
  # /(.)(.)(.)/.match!("abc")[2]   # => "b"
  # /(.)(.)/.match!("abc", 1)[2]   # => "c"
  # /(.)(タ)/.match!("クリスタル", 3)[2] # raises Exception
  # ```
  def match!(str : String, pos : Int32 = 0, *, options : Regex::MatchOptions = :none) : MatchData
    byte_index = str.char_index_to_byte_index(pos) || raise Error.new "Match not found"
    $~ = match_at_byte_index(str, byte_index, options) || raise Error.new "Match not found"
  end

  # Match at byte index. Matches a regular expression against `String`
  # *str*. Starts at the byte index given by *pos* if given, otherwise at
  # the start of *str*. Returns a `Regex::MatchData` if *str* matched, otherwise
  # `nil`. `$~` will contain the same value that was returned.
  #
  # ```
  # /(.)(.)(.)/.match_at_byte_index("abc").try &.[2]   # => "b"
  # /(.)(.)/.match_at_byte_index("abc", 1).try &.[2]   # => "c"
  # /(.)(.)/.match_at_byte_index("クリスタル", 3).try &.[2] # => "ス"
  # ```
  def match_at_byte_index(str : String, byte_index : Int32 = 0, options : Regex::MatchOptions = :none) : MatchData?
    if byte_index > str.bytesize
      $~ = nil
    else
      $~ = match_impl(str, byte_index, options)
    end
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def match_at_byte_index(str, byte_index = 0, *, options) : MatchData?
    if byte_index > str.bytesize
      $~ = nil
    else
      $~ = match_impl(str, byte_index, options)
    end
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def match_at_byte_index(str, byte_index, _options) : MatchData?
    match_at_byte_index(str, byte_index, options: _options)
  end

  # Match at character index. It behaves like `#match`, however it returns `Bool` value.
  # It neither returns `MatchData` nor assigns it to the `$~` variable.
  #
  # ```
  # /foo/.matches?("bar") # => false
  # /foo/.matches?("foo") # => true
  #
  # # `$~` is not set even if last match succeeds.
  # $~ # raises Exception
  # ```
  def matches?(str : String, pos : Int32 = 0, options : Regex::MatchOptions = :none) : Bool
    if byte_index = str.char_index_to_byte_index(pos)
      matches_at_byte_index?(str, byte_index, options)
    else
      false
    end
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def matches?(str, pos = 0, *, options) : Bool
    if byte_index = str.char_index_to_byte_index(pos)
      matches_at_byte_index?(str, byte_index, options)
    else
      false
    end
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def matches?(str, pos, _options) : Bool
    matches?(str, pos, options: _options)
  end

  # Match at byte index. It behaves like `#match_at_byte_index`, however it returns `Bool` value.
  # It neither returns `MatchData` nor assigns it to the `$~` variable.
  def matches_at_byte_index?(str : String, byte_index : Int32 = 0, options : Regex::MatchOptions = :none) : Bool
    return false if byte_index > str.bytesize

    matches_impl(str, byte_index, options)
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def matches_at_byte_index?(str, byte_index = 0, *, options) : Bool
    return false if byte_index > str.bytesize

    matches_impl(str, byte_index, options)
  end

  # :ditto:
  @[Deprecated("Use the overload with `Regex::MatchOptions` instead.")]
  def matches_at_byte_index?(str, byte_index, _options) : Bool
    matches_at_byte_index?(str, byte_index, options: _options)
  end

  # Returns a `Hash` where the values are the names of capture groups and the
  # keys are their indexes. Non-named capture groups will not have entries in
  # the `Hash`. Capture groups are indexed starting from `1`.
  #
  # ```
  # /(.)/.name_table                         # => {}
  # /(?<foo>.)/.name_table                   # => {1 => "foo"}
  # /(?<foo>.)(?<bar>.)/.name_table          # => {2 => "bar", 1 => "foo"}
  # /(.)(?<foo>.)(.)(?<bar>.)(.)/.name_table # => {4 => "bar", 2 => "foo"}
  # ```
  def name_table : Hash(Int32, String)
    name_table_impl
  end

  # Returns the number of (named & non-named) capture groups.
  #
  # ```
  # /(?:.+)/.capture_count     # => 0
  # /(?<foo>.+)/.capture_count # => 1
  # /(.)/.capture_count        # => 1
  # /(.)|(.)/.capture_count    # => 2
  # ```
  def capture_count : Int32
    capture_count_impl
  end

  # Convert to `String` in subpattern format. Produces a `String` which can be
  # embedded in another `Regex` via interpolation, where it will be interpreted
  # as a non-capturing subexpression in another regular expression.
  #
  # ```
  # re = /A*/i                 # => /A*/i
  # re.to_s                    # => "(?i-msx:A*)"
  # "Crystal".match(/t#{re}l/) # => Regex::MatchData("tal")
  # re = /A*/                  # => "(?-imsx:A*)"
  # "Crystal".match(/t#{re}l/) # => nil
  # ```
  def to_s(io : IO) : Nil
    io << "(?"
    io << 'i' if options.ignore_case?
    io << "ms" if options.multiline?
    io << 'x' if options.extended?

    io << '-'
    io << 'i' unless options.ignore_case?
    io << "ms" unless options.multiline?
    io << 'x' unless options.extended?

    io << ':'
    Regex.append_source(source, io)
    io << ')'
  end

  # :nodoc:
  def self.append_source(source : String, io : IO) : Nil
    reader = Char::Reader.new(source)
    while reader.has_next?
      case char = reader.current_char
      when '\\'
        io << '\\'
        io << reader.next_char
      when '/'
        io << "\\/"
      else
        io << char
      end
      reader.next_char
    end
  end

  def dup
    self
  end

  def clone : Regex
    self
  end
end
