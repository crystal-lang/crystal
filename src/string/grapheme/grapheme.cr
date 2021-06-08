require "./properties"

class String
  private def each_grapheme_boundary
    state = Grapheme::Property::Start

    reader = Char::Reader.new(self)
    last_char = reader.current_char
    # cache last_property to avoid re-calculation on the following iteration
    last_property = Grapheme::Property.from(last_char)
    last_boundary = 0

    while reader.has_next?
      char = reader.next_char
      property = Grapheme::Property.from(char)
      boundary = Grapheme.break?(last_property, property, pointerof(state))

      if boundary
        index = reader.pos
        yield last_boundary...index, last_char

        last_boundary = index
      end

      last_char = char
      last_property = property
    end
  end

  # :nodoc:
  class GraphemeIterator
    include Iterator(Grapheme)

    @last_char : Char
    @last_property : Grapheme::Property

    def initialize(str : String)
      @reader = Char::Reader.new(str)
      @state = Grapheme::Property::Start
      @last_char = @reader.current_char
      # cache last_property to avoid re-calculation on the following iteration
      @last_property = Grapheme::Property.from(@last_char)
      @last_boundary = 0
    end

    def next
      return stop unless @reader.has_next?

      while char = @reader.next_char
        property = Grapheme::Property.from(char)
        boundary = Grapheme.break?(@last_property, property, pointerof(@state))

        last_char = @last_char
        @last_char = char
        @last_property = property

        if boundary
          index = @reader.pos
          grapheme = Grapheme.new(@reader.string, @last_boundary...index, last_char)
          @last_boundary = index

          return grapheme
        end
      end

      Grapheme.new(@reader.string, @last_boundary..@reader.string.bytesize, @last_char)
    end
  end

  # `Grapheme` represents a Unicode grapheme cluster, which describes the smallest
  # functional unit of a writing system. This is also called a *user-perceived character*.
  #
  # In the latin alphabet, most graphemes consist of a single Unicode codepoint
  # (equivalent to `Char`). But a grapheme can also consiste of a sequence of codepoints,
  # which combine into a single unit.
  #
  # For example, the string `"e\u0301"` consists of two characters, the latin small letter `e`
  # and the combining acute accent `´`. Together, they form a single grapheme: `é`.
  # That same grapheme could alternatively be described in a single codepoint, `\u00E9` (latin small letter e with acute).
  # But the combinatory possibilities are far bigger than the amount of directly
  # available codepoints.
  #
  # ```
  # "e\u0301".size # => 2
  # "é".size       # => 1
  #
  # "e\u0301".grapheme_size # => 1
  # "é".grapheme_size       # => 1
  # ```
  #
  # Instances of this type can be acquired via `String#each_grapheme` or `String#graphemes`.
  #
  # The algorithm to determine boundaries between grapheme clusters is specified
  # in the [Unicode Standard Annex #29](https://www.unicode.org/reports/tr29/tr29-37.html#Grapheme_Cluster_Boundaries),
  # and implemented in Version Unicode 13.0.0.
  struct Grapheme
    @cluster : Char | String

    # :nodoc:
    def self.new(string : String, range : Range(Int32, Int32), char : Char)
      if char.bytesize == range.size
        new(char)
      else
        new(string.byte_slice(range.begin, range.end - range.begin))
      end
    end

    # :nodoc:
    def initialize(@cluster)
    end

    def to_s(io : IO) : Nil
      io << @cluster
    end

    def to_s : String
      case cluster = @cluster
      in Char
        cluster.to_s
      in String
        cluster
      end
    end

    def inspect(io : IO) : Nil
      io << "String::Grapheme("
      @cluster.inspect(io)
      io << ")"
    end

    def size
      case cluster = @cluster
      in Char
        1
      in String
        cluster.size
      end
    end

    def bytesize
      @cluster.bytesize
    end

    def ==(other : self)
      @cluster == other.@cluster
    end

    # :nodoc:
    def self.break?(c1 : Char, c2 : Char)
      break?(Property.from(c1), Property.from(c2))
    end

    # :nodoc:
    #
    # Returns whether there is a grapheme break between boundclasses lbc and tbc.
    #
    # Please note that evaluation of GB10 (grapheme breaks between emoji zwj sequences)
    # and GB 12/13 (regional indicator code points) require knowledge of previous characters
    # which is not handled by this oberload. This may result in an incorrect break before
    # an E_Modifier class codepoint and an incorrectly missing break between two
    # REGIONAL_INDICATOR class code points if such support does not exist in the caller.
    #
    # The rules are graphically displayed in a tyble on https://www.unicode.org/Public/13.0.0/ucd/auxiliary/GraphemeBreakTest.html
    #
    # The implementation is insipred by https://github.com/JuliaStrings/utf8proc/blob/462093b3924c7491defc67fda4bc7a27baf9b088/utf8proc.c#L261
    def self.break?(lbc : Property, tbc : Property)
      return true if lbc.start?                                                   # GB1
      return false if lbc.cr? && tbc.lf?                                          # GB3
      return true if lbc.cr? || lbc.lf? || lbc.control?                           # GB4
      return true if tbc.cr? || tbc.lf? || tbc.control?                           # GB5
      return false if lbc.l? && (tbc.l? || tbc.v? || tbc.lv? || tbc.lvt?)         # GB6
      return false if (lbc.lv? || lbc.v?) && (tbc.v? || tbc.t?)                   # GB7
      return false if (lbc.lvt? || lbc.t?) && tbc.t?                              # GB8
      return false if tbc.extend? || tbc.zwj?                                     # GB9
      return false if tbc.spacing_mark?                                           # GB9a
      return false if lbc.prepend?                                                # GB9b
      return false if lbc.extended_plus_zero_width? && tbc.extended_pictographic? # GB11 (requires additional handling)
      return false if lbc.regional_indicator? && tbc.regional_indicator?          # GB12/13 (requires additional handling)
      true                                                                        # GB999
    end

    # :nodoc:
    def self.break?(c1 : Char, c2 : Char, state : Pointer(Property))
      break?(Property.from(c1), Property.from(c2), state)
    end

    # :nodoc:
    #
    # Returns whether there is a grapheme break between boundclasses lbc and tbc.
    #
    # Please note that evaluation of GB10 (grapheme breaks between emoji zwj sequences)
    # and GB 12/13 (regional indicator code points) require knowledge of previous characters
    # which is accounted for in the state argument.
    #
    # The implementation is inspired by https://github.com/JuliaStrings/utf8proc/blob/462093b3924c7491defc67fda4bc7a27baf9b088/utf8proc.c#L291
    def self.break?(lbc : Property, tbc : Property, state : Pointer(Property))
      if state
        if state.value.start?
          state.value = lbc_override = lbc
        else
          lbc_override = state.value
        end

        break_permitted = break?(lbc_override, tbc)

        # Special support for GB 12/13 made possible by GB999. After two RI
        # class codepoints we want to force a break. Do this by resetting the
        # second RI's bound class to UTF8PROC_BOUNDCLASS_OTHER, to force a break
        # after that character according to GB999 (unless of course such a break is
        # forbidden by a different rule such as GB9).
        if state.value == tbc && tbc.regional_indicator?
          state.value = :any
          # Special support for GB11 (emoji extend* zwj / emoji)
        elsif state.value.extended_pictographic?
          if tbc.extend? # fold EXTEND codepoints into emoji
            state.value = :extended_pictographic
          elsif tbc.zwj?
            state.value = :extended_plus_zero_width # state to record emoji+zwg combo
          else
            state.value = tbc
          end
        else
          state.value = tbc
        end

        break_permitted
      else
        break?(lbc, tbc)
      end
    end
  end
end
