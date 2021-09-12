# Provides the `Unicode::CaseOptions` enum for special case conversions like Turkic.
module Unicode
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
    in_any_category?(char.ord, category_Lu, category_Ll, category_Lt)
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
