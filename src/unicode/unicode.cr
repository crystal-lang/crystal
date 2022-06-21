# Provides the `Unicode::CaseOptions` enum for special case conversions like Turkic.
module Unicode
  # The currently supported [Unicode](https://home.unicode.org) version.
  VERSION = "14.0.0"

  # Case options to pass to various `Char` and `String` methods such as `upcase` or `downcase`.
  @[Flags]
  enum CaseOptions
    # Only transform ASCII characters.
    ASCII

    # Use Turkic case rules:
    #
    # ```
    # 'İ'.downcase(Unicode::CaseOptions::Turkic) # => 'i'
    # 'I'.downcase(Unicode::CaseOptions::Turkic) # => 'ı'
    # 'i'.upcase(Unicode::CaseOptions::Turkic)   # => 'İ'
    # 'ı'.upcase(Unicode::CaseOptions::Turkic)   # => 'I'
    # ```
    Turkic

    # Unicode case folding, which is more far-reaching than Unicode case mapping.
    Fold
  end

  # :nodoc:
  # Returns whether the given *bytes* refer to a correctly encoded UTF-8 string.
  #
  # The implementation here uses a shift-based DFA based on
  # https://gist.github.com/pervognsen/218ea17743e1442e59bb60d29b1aa725.
  # This loop is very tight and bypasses `Char::Reader` completely. The downside
  # is that it does not compute anything else, such as the code points
  # themselves or their count, because the required handling for invalid byte
  # sequences would significantly slow down the loop.
  def self.valid?(bytes : Bytes) : Bool
    state = 0_u64
    table = UTF8_ENCODING_DFA.to_unsafe
    s = bytes.to_unsafe
    e = s + bytes.size

    # TODO: unroll?
    while s < e
      state = table[s.value].unsafe_shr(state & 0x3F)
      return false if state & 0x3F == 6
      s += 1
    end

    state & 0x3F == 0
  end

  private UTF8_ENCODING_DFA = begin
    x = Array(UInt64).new(256)

    # The same DFA transition table, with error state and unused bytes hidden:
    #
    #              accepted (initial state)
    #              | 1 continuation byte left
    #              | | 2 continuation bytes left
    #              | | | E0-?? ??; disallow overlong encodings up to U+07FF
    #              | | | | ED-?? ??; disallow surrogate pairs
    #              | | | | | F0-?? ?? ??; disallow overlong encodings up to U+FFFF
    #              | | | | | | 3 continuation bytes left
    #              | | | | | | | F4-?? ?? ??; disallow codepoints above U+10FFFF
    #              v v v v v v v v
    #
    #            | 0 2 3 4 5 6 7 8
    # -----------+----------------
    # 0x00..0x7F | 0 _ _ _ _ _ _ _
    # 0x80..0x8F | _ 0 2 _ 2 _ 3 3
    # 0x90..0x9F | _ 0 2 _ 2 3 3 _
    # 0xA0..0xBF | _ 0 2 2 _ 3 3 _
    # 0xC2..0xDF | 2 _ _ _ _ _ _ _
    # 0xE0..0xE0 | 4 _ _ _ _ _ _ _
    # 0xE1..0xEC | 3 _ _ _ _ _ _ _
    # 0xED..0xED | 5 _ _ _ _ _ _ _
    # 0xEE..0xEF | 3 _ _ _ _ _ _ _
    # 0xF0..0xF0 | 6 _ _ _ _ _ _ _
    # 0xF1..0xF3 | 7 _ _ _ _ _ _ _
    # 0xF4..0xF4 | 8 _ _ _ _ _ _ _

    {% for ch in 0x00..0x7F %} put1(x, dfa_state(0, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0x80..0x8F %} put1(x, dfa_state(1, 1, 0, 2, 1, 2, 1, 3, 3)); {% end %}
    {% for ch in 0x90..0x9F %} put1(x, dfa_state(1, 1, 0, 2, 1, 2, 3, 3, 1)); {% end %}
    {% for ch in 0xA0..0xBF %} put1(x, dfa_state(1, 1, 0, 2, 2, 1, 3, 3, 1)); {% end %}
    {% for ch in 0xC0..0xC1 %} put1(x, dfa_state(1, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xC2..0xDF %} put1(x, dfa_state(2, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xE0..0xE0 %} put1(x, dfa_state(4, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xE1..0xEC %} put1(x, dfa_state(3, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xED..0xED %} put1(x, dfa_state(5, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xEE..0xEF %} put1(x, dfa_state(3, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xF0..0xF0 %} put1(x, dfa_state(6, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xF1..0xF3 %} put1(x, dfa_state(7, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xF4..0xF4 %} put1(x, dfa_state(8, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}
    {% for ch in 0xF5..0xFF %} put1(x, dfa_state(1, 1, 1, 1, 1, 1, 1, 1, 1)); {% end %}

    x
  end

  private def self.put1(array : Array, value) : Nil
    array << value
  end

  private macro dfa_state(*transitions)
    {% x = 0_u64 %}
    {% for tr, i in transitions %}
      {% x |= (1_u64 << (i * 6)) * tr * 6 %}
    {% end %}
    {{ x }}
  end

  # :nodoc:
  def self.upcase(char : Char, options : CaseOptions) : Char
    result = check_upcase_ascii(char, options)
    return result if result

    result = check_upcase_turkic(char, options)
    return result if result

    check_upcase_ranges(char)
  end

  # :nodoc:
  def self.upcase(char : Char, options : CaseOptions)
    result = check_upcase_ascii(char, options)
    if result
      yield result
      return
    end

    result = check_upcase_turkic(char, options)
    if result
      yield result
      return
    end

    result = special_cases_upcase[char.ord]?
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    yield check_upcase_ranges(char)
  end

  private def self.check_upcase_ascii(char, options)
    if (char.ascii? && options.none?) || options.ascii?
      if char.ascii_lowercase?
        return (char.ord - 32).unsafe_chr
      else
        return char
      end
    end
    nil
  end

  private def self.check_upcase_turkic(char, options)
    if options.turkic?
      case char
      when 'ı' then 'I'
      when 'i' then 'İ'
      else          nil
      end
    else
      nil
    end
  end

  private def self.check_upcase_ranges(char)
    result = search_ranges(upcase_ranges, char.ord)
    return char + result if result

    result = search_alternate(alternate_ranges, char.ord)
    return char - 1 if result && (char.ord - result).odd?

    char
  end

  # :nodoc:
  def self.downcase(char : Char, options : CaseOptions) : Char
    result = check_downcase_ascii(char, options)
    return result if result

    result = check_downcase_turkic(char, options)
    return result if result

    results = check_downcase_fold(char, options)
    return results[0].unsafe_chr if results && results.size == 1

    check_downcase_ranges(char)
  end

  # :nodoc:
  def self.downcase(char : Char, options : CaseOptions)
    result = check_downcase_ascii(char, options)
    if result
      yield result
      return
    end

    result = check_downcase_turkic(char, options)
    if result
      yield result
      return
    end

    result = check_downcase_fold(char, options)
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    result = special_cases_downcase[char.ord]?
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    yield check_downcase_ranges(char)
  end

  private def self.check_downcase_ascii(char, options)
    if (char.ascii? && options.none?) || options.ascii?
      if char.ascii_uppercase?
        return (char.ord + 32).unsafe_chr
      else
        return char
      end
    end

    nil
  end

  private def self.check_downcase_turkic(char, options)
    if options.turkic?
      case char
      when 'I' then 'ı'
      when 'İ' then 'i'
      else          nil
      end
    else
      nil
    end
  end

  private def self.check_downcase_fold(char, options)
    if options.fold?
      result = search_ranges(casefold_ranges, char.ord)
      return {char.ord + result} if result

      return fold_cases[char.ord]?
    end
    nil
  end

  private def self.check_downcase_ranges(char)
    result = search_ranges(downcase_ranges, char.ord)
    return char + result if result

    result = search_alternate(alternate_ranges, char.ord)
    return char + 1 if result && (char.ord - result).even?

    char
  end

  # :nodoc:
  def self.lowercase?(char : Char) : Bool
    in_category?(char.ord, category_Ll)
  end

  # :nodoc:
  def self.uppercase?(char : Char) : Bool
    in_category?(char.ord, category_Lu)
  end

  # :nodoc:
  def self.letter?(char : Char) : Bool
    in_any_category?(char.ord, category_Lu, category_Ll, category_Lt, category_Lm, category_Lo)
  end

  # :nodoc:
  def self.number?(char : Char) : Bool
    in_any_category?(char.ord, category_Nd, category_Nl, category_No)
  end

  # :nodoc:
  def self.control?(char : Char) : Bool
    in_any_category?(char.ord, category_Cs, category_Co, category_Cn, category_Cf, category_Cc)
  end

  # :nodoc:
  def self.whitespace?(char : Char) : Bool
    in_any_category?(char.ord, category_Zs, category_Zl, category_Zp)
  end

  # :nodoc:
  def self.mark?(char : Char) : Bool
    in_any_category?(char.ord, category_Mn, category_Me, category_Mc)
  end

  private def self.search_ranges(haystack, needle)
    value = haystack.bsearch { |low, high, delta| needle <= high }
    if value && value[0] <= needle <= value[1]
      value[2]
    else
      nil
    end
  end

  private def self.search_alternate(haystack, needle)
    value = haystack.bsearch { |low, high| needle <= high }
    if value && value[0] <= needle <= value[1]
      value[0]
    else
      nil
    end
  end

  private def self.in_category?(needle, haystack)
    value = haystack.bsearch { |low, high, stride| needle <= high }
    if value && value[0] <= needle <= value[1]
      (needle - value[0]).divisible_by?(value[2])
    else
      false
    end
  end

  private def self.in_any_category?(needle, *haystacks) : Bool
    haystacks.any? { |haystack| in_category?(needle, haystack) }
  end
end

require "./data"
