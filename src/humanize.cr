struct Number
  # Prints this number as a `String` using a customizable format.
  #
  # *separator* is used as decimal separator, *delimiter* as thousands
  # delimiter between batches of *group* digits.
  #
  # If *decimal_places* is `nil`, all significant decimal places are printed
  # (similar to `#to_s`). If the argument has a numeric value, the number of
  # visible decimal places will be fixed to that amount.
  #
  # Trailing zeros are omitted if *only_significant* is `true`.
  #
  # ```
  # 123_456.789.format                                            # => "123,456.789"
  # 123_456.789.format(',', '.')                                  # => "123.456,789"
  # 123_456.789.format(decimal_places: 2)                         # => "123,456.79"
  # 123_456.789.format(decimal_places: 6)                         # => "123,456.789000"
  # 123_456.789.format(decimal_places: 6, only_significant: true) # => "123,456.789"
  # ```
  def format(io : IO, separator = '.', delimiter = ',', decimal_places : Int? = nil, *, group : Int = 3, only_significant : Bool = false) : Nil
    number = self
    # TODO: Optimize implementation for Int
    if decimal_places && (decimal_places < 0 || !number.is_a?(Float))
      number = number.round(decimal_places)
    end

    if number.is_a?(Float)
      if number.infinite?
        if number < 0
          io << '-'
        end
        io << "Infinity"
        return
      elsif number.nan?
        io << "NaN"
        return
      end

      if decimal_places && decimal_places >= 0
        string = "%.*f" % {decimal_places, number.abs}
        integer, _, decimals = string.partition('.')
      else
        string = String.build do |io|
          # Make sure to avoid scientific notation of default Float#to_s
          Float::Printer.shortest(number.abs, io, point_range: ..)
        end
        _, _, decimals = string.partition(".")
        integer = "%.0f" % number.trunc.abs
      end
    elsif number.is_a?(Int)
      integer = number.abs.to_s
      decimals = ""
    else
      # TODO: optimize for BigDecimal
      string = number.abs.to_s
      integer, _, decimals = string.partition('.')
    end

    is_negative = number.responds_to?(:sign_bit) ? number.sign_bit < 0 : number < 0

    format_impl(io, is_negative, integer, decimals, separator, delimiter, decimal_places, group, only_significant)
  end

  # :ditto:
  def format(separator = '.', delimiter = ',', decimal_places : Int? = nil, *, group : Int = 3, only_significant : Bool = false) : String
    String.build do |io|
      format(io, separator, delimiter, decimal_places, group: group, only_significant: only_significant)
    end
  end

  private def format_impl(io, is_negative, integer, decimals, separator, delimiter, decimal_places, group, only_significant) : Nil
    int_size = integer.size
    dec_size = decimals.size

    io << '-' if is_negative

    start = int_size % group
    start += group if start == 0
    io.write_string integer.to_slice[0, start]

    while start < int_size
      io << delimiter
      io.write_string integer.to_slice[start, group]
      start += group
    end

    decimal_places ||= dec_size

    if decimal_places > 0
      io << separator
      if only_significant
        decimals = decimals.rstrip('0')
        if decimals.empty?
          io << '0'
        else
          io << decimals
        end
      else
        io << decimals
        (decimal_places - dec_size).times do
          io << '0'
        end
      end
    end
  end

  # Default SI prefixes ordered by magnitude.
  SI_PREFIXES = { {'q', 'r', 'y', 'z', 'a', 'f', 'p', 'n', 'µ', 'm'}, {nil, 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y', 'R', 'Q'} }

  # SI prefixes used by `#humanize`. Equal to `SI_PREFIXES` but prepends the
  # prefix with a space character.
  SI_PREFIXES_PADDED = ->(magnitude : Int32, _number : Float64) do
    magnitude = Number.prefix_index(magnitude)
    {magnitude, (magnitude == 0 ? " " : si_prefix(magnitude))}
  end

  # Returns the SI prefix for *magnitude*.
  #
  # ```
  # Number.si_prefix(3) # => 'k'
  # ```
  def self.si_prefix(magnitude : Int, prefixes = SI_PREFIXES) : Char?
    index = (magnitude // 3)
    prefixes = prefixes[magnitude < 0 ? 0 : 1]
    prefixes[index.clamp((-prefixes.size)..(prefixes.size - 1))]
  end

  # :nodoc:
  def self.prefix_index(i : Int32, *, group : Int32 = 3, prefixes = SI_PREFIXES) : Int32
    prefixes = prefixes[i < 0 ? 0 : 1]
    ((i - (i > 0 ? 1 : 0)) // group).clamp((-prefixes.size)..(prefixes.size - 1)) * group
  end

  # Pretty prints this number as a `String` in a human-readable format.
  #
  # This is particularly useful if a number can have a wide value range and
  # the *exact* value is less relevant.
  #
  # It rounds the number to the nearest thousands magnitude with *precision*
  # number of significant digits. The order of magnitude is expressed with an
  # appended quantifier.
  # By default, SI prefixes are used (see `SI_PREFIXES`).
  #
  # ```
  # 1_200_000_000.humanize # => "1.2G"
  # 0.000_000_012.humanize # => "12.0n"
  # ```
  #
  # If *significant* is `false`, the number of *precision* digits is preserved
  # after the decimal separator.
  #
  # ```
  # 1_234.567_890.humanize(precision: 2)                     # => "1.2k"
  # 1_234.567_890.humanize(precision: 2, significant: false) # => "1.23k"
  # ```
  #
  # *separator* describes the decimal separator, *delimiter* the thousands
  # delimiter (see `#format`).
  #
  # *unit_separator* is inserted between the value and the unit.
  # Users are encouraged to use a non-breaking space ('\u00A0') to prevent output being split across lines.
  #
  # See `Int#humanize_bytes` to format a file size.
  def humanize(io : IO, precision = 3, separator = '.', delimiter = ',', *, base = 10 ** 3, significant = true, unit_separator = nil, prefixes : Indexable = SI_PREFIXES) : Nil
    humanize(io, precision, separator, delimiter, base: base, significant: significant, unit_separator: unit_separator) do |magnitude, _|
      magnitude = Number.prefix_index(magnitude, prefixes: prefixes)
      {magnitude, Number.si_prefix(magnitude, prefixes)}
    end
  end

  # :ditto:
  def humanize(precision = 3, separator = '.', delimiter = ',', *, base = 10 ** 3, significant = true, unit_separator = nil, prefixes = SI_PREFIXES) : String
    String.build do |io|
      humanize(io, precision, separator, delimiter, base: base, significant: significant, unit_separator: unit_separator, prefixes: prefixes)
    end
  end

  # Pretty prints this number as a `String` in a human-readable format.
  #
  # This is particularly useful if a number can have a wide value range and
  # the *exact* value is less relevant.
  #
  # It rounds the number to the nearest thousands magnitude with *precision*
  # number of significant digits. The order of magnitude is expressed with an
  # appended quantifier.
  # By default, SI prefixes are used (see `SI_PREFIXES`).
  #
  # ```
  # 1_200_000_000.humanize # => "1.2G"
  # 0.000_000_012.humanize # => "12.0n"
  # ```
  #
  # If *significant* is `false`, the number of *precision* digits is preserved
  # after the decimal separator.
  #
  # ```
  # 1_234.567_890.humanize(precision: 2)                     # => "1.2k"
  # 1_234.567_890.humanize(precision: 2, significant: false) # => "1.23k"
  # ```
  #
  # *separator* describes the decimal separator, *delimiter* the thousands
  # delimiter (see `#format`).
  #
  # This methods yields the order of magnitude and `self` and expects the block
  # to return a `Tuple(Int32, _)` containing the (adjusted) magnitude and unit.
  # The magnitude is typically adjusted to a multiple of `3`.
  #
  # ```
  # def humanize_length(number)
  #   number.humanize do |magnitude, number|
  #     case magnitude
  #     when -2, -1 then {-2, " cm"}
  #     when .>=(4)
  #       {3, " km"}
  #     else
  #       magnitude = Number.prefix_index(magnitude)
  #       {magnitude, " #{Number.si_prefix(magnitude)}m"}
  #     end
  #   end
  # end
  #
  # humanize_length(1_420) # => "1.42 km"
  # humanize_length(0.23)  # => "23.0 cm"
  # ```
  #
  # See `Int#humanize_bytes` to format a file size.
  def humanize(io : IO, precision = 3, separator = '.', delimiter = ',', *, base = 10 ** 3, significant = true, unit_separator = nil, &prefixes : (Int32, Float64) -> {Int32, _} | {Int32, _, Bool}) : Nil
    if zero? || (responds_to?(:infinite?) && self.infinite?) || (responds_to?(:nan?) && self.nan?)
      digits = 0
    else
      log = Math.log10(abs)
      digits = log.floor.to_i + 1
    end

    magnitude = digits

    proper_fraction = 0 < abs < 1
    if proper_fraction
      magnitude -= 1
    elsif magnitude == 0
      magnitude = 1
    end

    yield_result = yield magnitude, self.to_f
    magnitude, unit = yield_result[0..1]

    decimal_places = precision
    if significant
      scrap_digits = digits - precision
      decimal_places += magnitude - digits
    else
      scrap_digits = magnitude - precision
    end
    scrap_digits *= -1 if proper_fraction

    exponent = 10 ** scrap_digits.to_f
    if proper_fraction
      number = (to_f * exponent).round / exponent
    else
      number = (to_f / exponent).round * exponent
    end

    number /= base.to_f ** (magnitude.to_f / 3.0)

    # Scrap decimal places if magnitude lower bound == 0
    # to return e.g. "1B" instead of "1.0B" for humanize_bytes.
    decimal_places = 0 if yield_result[2]? == false

    number.format(io, separator, delimiter, decimal_places: decimal_places, only_significant: significant)

    io << unit_separator if unit
    io << unit
  end

  # :ditto:
  def humanize(precision = 3, separator = '.', delimiter = ',', *, base = 10 ** 3, significant = true, unit_separator = nil, &) : String
    String.build do |io|
      humanize(io, precision, separator, delimiter, base: base, significant: significant, unit_separator: unit_separator) do |magnitude, number|
        yield magnitude, number
      end
    end
  end

  # :ditto:
  def humanize(io : IO, precision = 3, separator = '.', delimiter = ',', *, base = 10 ** 3, significant = true, unit_separator = nil, prefixes : Proc) : Nil
    humanize(io, precision, separator, delimiter, base: base, significant: significant, unit_separator: unit_separator) do |magnitude, number|
      prefixes.call(magnitude, number)
    end
  end

  # :ditto:
  def humanize(precision = 3, separator = '.', delimiter = ',', *, base = 10 ** 3, significant = true, unit_separator = nil, prefixes : Proc) : String
    String.build do |io|
      humanize(io, precision, separator, delimiter, base: base, significant: significant, unit_separator: unit_separator, prefixes: prefixes)
    end
  end
end

struct Int
  enum BinaryPrefixFormat
    # The IEC standard prefixes (`Ki`, `Mi`, `Gi`, `Ti`, `Pi`, `Ei`, `Zi`, `Yi`, `Ri`, `Qi`)
    # based on powers of 1000.
    IEC

    # Extended range of the JEDEC units (`K`, `M`, `G`, `T`, `P`, `E`, `Z`, `Y`, `R`, `Q`)
    # which equals to the prefixes of the SI system except for uppercase `K` and
    # is based on powers of 1024.
    JEDEC
  end

  # Prints this integer as a binary value in a human-readable format using
  # a `BinaryPrefixFormat`.
  #
  # Values with binary measurements such as computer storage (e.g. RAM size) are
  # typically expressed using unit prefixes based on 1024 (instead of multiples
  # of 1000 as per SI standard). This method by default uses the IEC standard
  # prefixes (`Ki`, `Mi`, `Gi`, `Ti`, `Pi`, `Ei`, `Zi`, `Yi`, `Ri`, `Qi`) based
  # on powers of 1000 (see `BinaryPrefixFormat::IEC`).
  #
  # *format* can be set to use the extended range of JEDEC units (`K`, `M`, `G`,
  # `T`, `P`, `E`, `Z`, `Y`, `R`, `Q`) which equals to the prefixes of the SI
  # system except for uppercase `K` and is based on powers of 1024 (see
  # `BinaryPrefixFormat::JEDEC`).
  #
  # ```
  # 1.humanize_bytes                        # => "1B"
  # 1024.humanize_bytes                     # => "1.0kiB"
  # 1536.humanize_bytes                     # => "1.5kiB"
  # 524288.humanize_bytes                   # => "512kiB"
  # 1073741824.humanize_bytes(format: :IEC) # => "1.0GiB"
  # ```
  #
  # See `Number#humanize` for more details on the behaviour and arguments.
  def humanize_bytes(io : IO, precision : Int = 3, separator = '.', *, significant : Bool = true, unit_separator = nil, format : BinaryPrefixFormat = :IEC) : Nil
    humanize(io, precision, separator, nil, base: 1024, significant: significant, unit_separator: unit_separator) do |magnitude|
      magnitude = Number.prefix_index(magnitude)

      prefix = Number.si_prefix(magnitude)
      if prefix.nil?
        unit = "B"
      else
        if format.iec?
          unit = "#{prefix}iB"
        else
          unit = "#{prefix.upcase}B"
        end
      end
      {magnitude, unit, magnitude > 0}
    end
  end

  # :ditto:
  def humanize_bytes(precision : Int = 3, separator = '.', *, significant : Bool = true, unit_separator = nil, format : BinaryPrefixFormat = :IEC) : String
    String.build do |io|
      humanize_bytes(io, precision, separator, significant: significant, unit_separator: unit_separator, format: format)
    end
  end
end
