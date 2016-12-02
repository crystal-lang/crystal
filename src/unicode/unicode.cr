# Provides methods that answer questions about unicode characters,
# and the `Unicode::CaseOptions` enum for special case conversions
# like turkic.
#
# There's no need to use the methods defined in this module
# because they are exposed in `Char` in a more convenient way
# (`Char#upcase`, `Char#downcase`, `Char#whitespace?`, etc.)
module Unicode
  # Options to pass to `upcase`, `downcase`, `uppercase?`
  # and `lowercase?` to control their behaviour.
  @[Flags]
  enum CaseOptions
    # Only transform ASCII characters.
    ASCII

    # Use turkic case rules:
    #
    # ```
    # 'İ'.downcase(Unicode::CaseOptions::Turikic) # => 'i'
    # 'I'.downcase(Unicode::CaseOptions::Turikic) # => 'ı'
    # 'i'.upcase(Unicode::CaseOptions::Turikic)   # => 'İ'
    # 'ı'.upcase(Unicode::CaseOptions::Turikic)   # => 'I'
    # ```
    Turkic
  end

  def self.upcase(char : Char, options : CaseOptions)
    result = check_upcase_ascii(char, options)
    return result if result

    result = check_upcase_turkic(char, options)
    return result if result

    check_upcase_ranges(char)
  end

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
    if (char.ascii? && options == Unicode::CaseOptions::None) || options.ascii?
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
      when 'ı'; return 'I'
      when 'i'; return 'İ'
      end
    end
    nil
  end

  private def self.check_upcase_ranges(char)
    result = search_ranges(upcase_ranges, char.ord)
    return char + result if result

    result = search_alternate(alternate_ranges, char.ord)
    return char - 1 if result && (char.ord - result).odd?

    char
  end

  def self.downcase(char : Char, options : CaseOptions)
    result = check_downcase_ascii(char, options)
    return result if result

    result = check_downcase_turkic(char, options)
    return result if result

    check_downcase_ranges(char)
  end

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

    result = special_cases_downcase[char.ord]?
    if result
      result.each { |c| yield c.unsafe_chr if c != 0 }
      return
    end

    yield check_downcase_ranges(char)
  end

  private def self.check_downcase_ascii(char, options)
    if (char.ascii? && options == Unicode::CaseOptions::None) || options.ascii?
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
      when 'I'; return 'ı'
      when 'İ'; return 'i'
      end
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

  def self.lowercase?(char : Char)
    in_category?(char.ord, category_Ll)
  end

  def self.uppercase?(char : Char)
    in_category?(char.ord, category_Lu)
  end

  def self.letter?(char : Char)
    in_any_category?(char.ord, category_Lu, category_Ll, category_Lt)
  end

  def self.number?(char : Char)
    in_any_category?(char.ord, category_Nd, category_Nl, category_No)
  end

  def self.control?(char : Char)
    in_any_category?(char.ord, category_Cs, category_Co, category_Cn, category_Cf, category_Cc)
  end

  def self.whitespace?(char : Char)
    in_any_category?(char.ord, category_Zs, category_Zl, category_Zp)
  end

  def self.mark?(char : Char)
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

  def self.in_any_category?(needle, *haystacks)
    haystacks.any? { |haystack| in_category?(needle, haystack) }
  end
end

require "./data"
