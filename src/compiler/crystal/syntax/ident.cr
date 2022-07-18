module Crystal
  struct Ident
    include Comparable(Ident)

    def initialize(@string : String)
    end

    delegate :empty?,
      :starts_with?,
      :ends_with?,
      :size,
      to: @string

    def ==(other : String)
      {% raise "Comparison between Ident and String is not allowed" %}
    end

    def ==(other : Ident)
      @string.same?(other.@string)
    end

    def <=>(other : Ident)
      @string <=> other.@string
    end

    def hash(hasher)
      hasher.int(@string.object_id)
    end

    def to_s : String
      @string
    end

    def to_s(io : IO) : Nil
      @string.to_s(io)
    end

    def inspect(io : IO) : Nil
      @string.inspect(io)
    end

    def clone
      self
    end
  end
end

class String
  def ==(other : Crystal::Ident)
    {% raise "Comparison between String and Ident is not allowed" %}
  end
end
