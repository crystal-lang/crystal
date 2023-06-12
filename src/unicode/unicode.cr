# Provides the `Unicode::CaseOptions` enum for special case conversions like Turkic.
module Unicode
  # The currently supported [Unicode](https://home.unicode.org) version.
  VERSION = "15.0.0"

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
    #
    # Note that only full mappings are defined, and calling `Char#downcase` with
    # this option will return its receiver unchanged if a multiple-character
    # case folding exists, even if a separate single-character transformation is
    # also defined in Unicode.
    #
    # ```
    # "ẞ".downcase(Unicode::CaseOptions::Fold) # => "ss"
    # 'ẞ'.downcase(Unicode::CaseOptions::Fold) # => 'ẞ' # not U+00DF 'ß'
    #
    # "ᾈ".downcase(Unicode::CaseOptions::Fold) # => "ἀι"
    # 'ᾈ'.downcase(Unicode::CaseOptions::Fold) # => "ᾈ" # not U+1F80 'ᾀ'
    # ```
    Fold
  end

  # Normalization forms available for `String#unicode_normalize` and
  # `String#unicode_normalized?`.
  enum NormalizationForm
    # Canonical decomposition.
    NFD

    # Canonical decomposition, followed by canonical composition.
    NFC

    # Compatibility decomposition.
    NFKD

    # Compatibility decomposition, followed by canonical composition.
    NFKC
  end

  # :nodoc:
  enum QuickCheckResult
    Yes
    No
    Maybe
  end

  private UNROLL = 64

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

    while s + UNROLL <= e
      {% for i in 0...UNROLL %}
        state = table[s[{{ i }}]].unsafe_shr(state & 0x3F)
      {% end %}
      return false if state & 0x3F == 6
      s += UNROLL
    end

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

  # TODO: remove the workaround for 1.0.0 eventually (needed until #10713)
  private macro dfa_state(*transitions)
    {% if compare_versions(Crystal::VERSION, "1.1.0") >= 0 %}
      {% x = 0_u64 %}
      {% for tr, i in transitions %}
        {% x |= (1_u64 << (i * 6)) * tr * 6 %}
      {% end %}
      {{ x }}
    {% else %}
      {% x = [] of Nil %}
      {% for tr, i in transitions %}
        {% x << "(#{tr * 6}_u64 << #{i * 6})" %}
      {% end %}
      {{ x.join(" | ").id }}
    {% end %}
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
  def self.upcase(char : Char, options : CaseOptions, &)
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

    check_downcase_ranges(char)
  end

  # :nodoc:
  def self.downcase(char : Char, options : CaseOptions, &)
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

  private def self.check_downcase_ranges(char)
    result = search_ranges(downcase_ranges, char.ord)
    return char + result if result

    result = search_alternate(alternate_ranges, char.ord)
    return char + 1 if result && (char.ord - result).even?

    char
  end

  # :nodoc:
  def self.titlecase(char : Char, options : CaseOptions) : Char
    result = check_upcase_ascii(char, options)
    return result if result

    result = check_upcase_turkic(char, options)
    return result if result

    # there are no ASCII or Turkic special cases for titlecasing; this is the
    # only part that differs from `.upcase`
    result = special_cases_titlecase[char.ord]?
    return result.first.unsafe_chr if result && result[1] == 0 && result[2] == 0

    check_upcase_ranges(char)
  end

  # :nodoc:
  def self.titlecase(char : Char, options : CaseOptions, &)
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

    # there are no ASCII or Turkic special cases for titlecasing; this is the
    # only part that differs from `.upcase`
    result = special_cases_titlecase[char.ord]?
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    result = special_cases_upcase[char.ord]?
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    yield check_upcase_ranges(char)
  end

  def self.foldcase(char : Char, options : CaseOptions) : Char
    results = check_foldcase(char, options)
    return results[0].unsafe_chr if results && results.size == 1

    char
  end

  # :nodoc:
  def self.foldcase(char : Char, options : CaseOptions, &)
    result = check_foldcase(char, options)
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    yield char
  end

  private def self.check_foldcase(char, options)
    if options.fold?
      result = search_ranges(casefold_ranges, char.ord)
      return {char.ord + result} if result

      return fold_cases[char.ord]?
    end
    nil
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
  def self.titlecase?(char : Char) : Bool
    in_category?(char.ord, category_Lt)
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

  # :nodoc:
  def self.canonical_decompose(all_codepoints : Array(Int32), char : Char)
    canonical_decompose(all_codepoints, char.ord)
  end

  private def self.canonical_decompose(all_codepoints : Array(Int32), codepoint : Int32)
    if Hangul.canonical_decompose(all_codepoints, codepoint)
      # do nothing
    elsif mapping = canonical_decompositions[codepoint]?
      first, second = mapping
      canonical_decompose(all_codepoints, first)
      canonical_decompose(all_codepoints, second) unless second.zero?
    else
      all_codepoints << codepoint
    end
  end

  # :nodoc:
  def self.compatibility_decompose(all_codepoints : Array(Int32), char : Char)
    compatibility_decompose(all_codepoints, char.ord)
  end

  private def self.compatibility_decompose(all_codepoints : Array(Int32), codepoint : Int32)
    if Hangul.canonical_decompose(all_codepoints, codepoint)
      # do nothing
    elsif mapping = canonical_decompositions[codepoint]?
      first, second = mapping
      compatibility_decompose(all_codepoints, first)
      compatibility_decompose(all_codepoints, second) unless second.zero?
    elsif mapping = compatibility_decompositions[codepoint]?
      index, count = mapping
      count.times do |i|
        part = compatibility_decomposition_data.unsafe_fetch(index + i)
        compatibility_decompose(all_codepoints, part)
      end
    else
      all_codepoints << codepoint
    end
  end

  # :nodoc:
  def self.canonical_order!(codepoints : Array(Int32))
    canonical_order!(Slice.new(codepoints.to_unsafe, codepoints.size))
  end

  private def self.canonical_order!(codepoints : Slice(Int32))
    i = 0

    # if `i == codepoints.size - 1` there cannot be a subsequence of 2
    # orderable codepoints, so we skip the last codepoint
    while i < codepoints.size - 1
      i_ord = codepoints.unsafe_fetch(i)
      i_ccc = canonical_combining_class(i_ord)
      if i_ccc == 0
        i += 1
        next
      end

      j = i + 1
      j_ord = codepoints.unsafe_fetch(j)
      j_ccc = canonical_combining_class(j_ord)
      if j_ccc == 0
        i += 2
        next
      end

      # subsequence of at least 2 codepoints with non-zero ccc; sort by their
      # ccc in ascending order (we hand-roll our own `sort_by!` so avoid
      # recomputing `i_ccc` and `j_ccc`)
      cccs = [{i_ord, i_ccc}, {j_ord, j_ccc}]
      j += 1
      while j < codepoints.size
        j_ord = codepoints.unsafe_fetch(j)
        j_ccc = canonical_combining_class(j_ord)
        break if j_ccc == 0
        cccs << {j_ord, j_ccc}
        j += 1
      end

      cccs.sort! { |x, y| x[1] <=> y[1] }
      cccs.each_with_index do |(ord, _), k|
        codepoints.unsafe_put(i + k, ord)
      end

      i = j + 1 # we can skip one codepoint as its ccc must be 0
    end
  end

  # :nodoc:
  def self.canonical_compose!(codepoints : Array(Int32), & : Char ->)
    canonical_compose!(Slice.new(codepoints.to_unsafe, codepoints.size)) { |x| yield x.unsafe_chr }
  end

  private def self.canonical_compose!(codepoints : Slice(Int32), & : Int32 ->)
    l_pos = 0
    l = codepoints.unsafe_fetch(l_pos)
    l_ccc = 0_u8

    (1...codepoints.size).each do |c_pos|
      c = codepoints.unsafe_fetch(c_pos)
      c_ccc = canonical_combining_class(c)

      if (c_ccc > l_ccc || l_ccc == 0) && (combined = canonical_composition(l, c))
        l = combined
        l_ccc = canonical_combining_class(l)
        codepoints.unsafe_put(c_pos, -1)
      elsif c_ccc == 0
        yield l
        while true
          l_pos += 1
          break if l_pos == c_pos
          l = codepoints.unsafe_fetch(l_pos)
          yield l unless l == -1
        end
        l = c
        l_ccc = 0_u8
      else
        l_ccc = c_ccc
      end
    end

    yield l
    while true
      l_pos += 1
      break if l_pos == codepoints.size
      l = codepoints.unsafe_fetch(l_pos)
      yield l unless l == -1
    end
  end

  # :nodoc:
  def self.quick_check_normalized(str : String, form : NormalizationForm) : QuickCheckResult
    result = QuickCheckResult::Yes
    return result if str.ascii_only?
    last_ccc = 0_u8

    str.each_codepoint do |codepoint|
      ccc = canonical_combining_class(codepoint)
      return QuickCheckResult::No if last_ccc > ccc && ccc != 0

      allowed = case form
                in .nfc?
                  search_ranges(nfc_quick_check, codepoint) { |x| x[2] }
                in .nfd?
                  search_ranges(nfd_quick_check, codepoint) { QuickCheckResult::No }
                in .nfkc?
                  search_ranges(nfkc_quick_check, codepoint) { |x| x[2] }
                in .nfkd?
                  search_ranges(nfkd_quick_check, codepoint) { QuickCheckResult::No }
                end

      if allowed
        return QuickCheckResult::No if allowed.no?
        result = QuickCheckResult::Maybe if allowed.maybe?
      end

      last_ccc = ccc
    end

    result
  end

  private def self.canonical_combining_class(codepoint : Int32) : UInt8
    search_ranges(canonical_combining_classes, codepoint) || 0_u8
  end

  private def self.canonical_composition(first : Int32, second : Int32)
    Hangul.canonical_composition(first, second) || canonical_compositions[(first.to_i64 << 21) | second]?
  end

  # For the meanings of these constants refer to the Unicode Standard, Chapter
  # 3.12 "Conjoining Jamo Behavior", in particular the subsection "Sample Code
  # for Hangul Algorithms"
  private module Hangul
    S_BASE  = 0xAC00
    L_BASE  = 0x1100
    V_BASE  = 0x1161
    T_BASE  = 0x11A7
    L_COUNT =     19
    V_COUNT =     21
    T_COUNT =     28
    N_COUNT = V_COUNT * T_COUNT # 588
    S_COUNT = L_COUNT * N_COUNT # 11172

    def self.canonical_decompose(all_codepoints : Array(Int32), codepoint : Int32)
      return false unless Hangul::S_BASE <= codepoint < Hangul::S_BASE + Hangul::S_COUNT
      s_index = codepoint - S_BASE

      l = L_BASE + s_index // N_COUNT
      v = V_BASE + (s_index % N_COUNT) // T_COUNT
      t = T_BASE + s_index % T_COUNT

      all_codepoints << l
      all_codepoints << v
      all_codepoints << t unless t == T_BASE

      true
    end

    def self.canonical_composition(first : Int32, second : Int32)
      # <L, V> composition
      if (L_BASE <= first < L_BASE + L_COUNT) && (V_BASE <= second < V_BASE + V_COUNT)
        l_index = first - L_BASE
        v_index = second - V_BASE
        lv_index = l_index * N_COUNT + v_index * T_COUNT
        return S_BASE + lv_index
      end

      # <LV, T> composition (note that t_index cannot be zero)
      s_index = first - S_BASE
      if (0 <= s_index < S_COUNT) && s_index % T_COUNT == 0 && (T_BASE < second < T_BASE + T_COUNT)
        t_index = second - T_BASE
        return first + t_index
      end
    end
  end

  private def self.search_ranges(haystack, needle, &)
    value = haystack.bsearch { |v| needle <= v[1] }
    if value && value[0] <= needle <= value[1]
      yield value
    else
      nil
    end
  end

  private def self.search_ranges(haystack, needle)
    search_ranges(haystack, needle) { |value| value[2] }
  end

  private def self.search_alternate(haystack, needle)
    search_ranges(haystack, needle) { |value| value[0] }
  end

  private def self.in_category?(needle, haystack)
    !!search_ranges(haystack, needle) { |value| (needle - value[0]).divisible_by?(value[2]) }
  end

  private def self.in_any_category?(needle, *haystacks) : Bool
    haystacks.any? { |haystack| in_category?(needle, haystack) }
  end
end

require "./data"
