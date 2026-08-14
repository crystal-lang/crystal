module Crystal::DWARF
  struct Abbrev
    struct Attribute
      getter at : UInt32
      getter form : UInt32
      getter const_value : Int32

      def initialize(@at, @form, @const_value)
      end
    end

    getter code : UInt32
    getter tag : UInt32
    getter? children : Bool

    def initialize(@code, @tag, @children, @reader : Reader*)
    end

    # Iterates every `Attribute`.
    def each_attribute(&) : Nil
      while true
        at = @reader.value.read_uleb128
        form = @reader.value.read_uleb128
        break if at == 0 && form == 0

        const_value = 0
        const_value = @reader.value.read_sleb128 if form == DW_FORM_implicit_const

        yield Attribute.new(at, form, const_value)
      end
    end
  end

  # Iterates every `Abbrev` in *bytes* until a code 0 is reached.
  #
  # WARNING: The caller must call `Abbrev#each_attribute` to advance the reader,
  # otherwise the iteration will fail.
  #
  # WARNING: Calling `Abbrev#each_attribute` after the block returned is
  # undefined behavior.
  def self.each_abbrev(bytes : Bytes, & : Abbrev ->) : Nil
    reader = Reader.new(bytes)

    while true
      offset = reader.pos
      code = reader.read_uleb128
      break if code == 0

      tag = reader.read_uleb128
      children = reader.read_u8 == 1

      yield Abbrev.new(code, tag, children, pointerof(reader)), offset
    end
  end

  # Parses the `Abbrev` located at *bytes.
  #
  # WARNING: Calling `Abbrev#each_attribute` after the block returned is
  # undefined behavior.
  def self.abbrev_at(bytes : Bytes, & : Abbrev ->) : Nil
    reader = Reader.new(bytes)

    code = reader.read_uleb128
    return if code == 0

    tag = reader.read_uleb128
    children = reader.read_u8 == 1

    yield Abbrev.new(code, tag, children, pointerof(reader))
  end

  # Searches the first `Abbrev` in *bytes* that matches *code*, yields it, then
  # returns. Raises when no abbrev can be found for *code*.
  #
  # WARNING: Calling `Abbrev#each_attribute` after the block returned is
  # undefined behavior.
  def self.lookup_abbrev(bytes : Bytes, code : Int, & : Abbrev ->) : Nil
    each_abbrev(bytes, _) do |abbrev|
      if abbrev.code == code
        yield abbrev
        return
      else
        abbrev.each_attribute { }
      end
    end
    raise Error.new("failed to find abbrev code=#{code}")
  end
end
