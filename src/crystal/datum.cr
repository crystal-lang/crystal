module Crystal
  # :nodoc:
  macro datum_accessors(short, type, immutable)
    # Checks that the underlying value is `{{ type }}`, and returns its value.
    # Raises otherwise.
    def as_{{ short.id }} : {{ type }}
      {% if immutable == true %}
        @raw.as({{ type }}).clone
      {% else %}
        @raw.as({{ type }})
      {% end %}
    end

    {% if type.resolve != Nil %}
      # Checks that the underlying value is `{{ type }}`, and returns its value.
      # Returns `nil` otherwise.
      def as_{{ short.id }}? : {{ type }}?
        {% if immutable == true %}
          @raw.as?({{ type }}).clone
        {% else %}
          @raw.as?({{ type }})
        {% end %}
      end
    {% end %}
  end

  # `Crystal.datum` macro is an internal helper to create data types that will hold
  # values of multiple kinds similar to `JSON::Any` and `YAML::Any`.
  #
  # * **types**: contains a named tuple of prefixes and data types of each leaf
  # * **hash_key_type** specifies the type used as the key of `Hash`
  # * **immutable**: will generate honor immutability of the values via `.clone`
  # * **target_type**: is the type where the macro is invoked (it's a workaround for #9099).

  # :nodoc:
  macro datum(*, types, hash_key_type, immutable, target_type)

    # All possible `{{ target_type }}` types.
    alias Type = {% for short, type in types %}{{ type }} | {% end %}Array(self) | Hash({{ hash_key_type }}, self)

    # Returns the raw underlying value, a `Type`.
    getter raw : Type

    # Creates a `{{ target_type }}` that wraps the given `Type`.
    def initialize(@raw : Type)
    end

    Crystal.datum_accessors a, Array(self), {{ immutable }}
    Crystal.datum_accessors h, Hash({{ hash_key_type }}, self), {{ immutable }}

    {% for short, type in types %}
      Crystal.datum_accessors {{ short }}, {{ type }}, {{ immutable }}
    {% end %}

    # Assumes the underlying value is an `Array` or `Hash` and returns its size.
    #
    # Raises if the underlying value is not an `Array` or `Hash`.
    def size : Int
      case object = @raw
      when Array
        object.size
      when Hash
        object.size
      else
        raise "Expected Array or Hash for #size, not #{object.class}"
      end
    end

    # Assumes the underlying value is an `Array` or `Hash`
    # and returns the element at the given *index_or_key*.
    #
    # Raises if the underlying value is not an `Array` nor a `Hash`.
    def [](index_or_key) : self
      case object = @raw
      when Array
        if index_or_key.is_a?(Int)
          object[index_or_key]
        else
          raise "Expected int key for Array#[], not #{object.class}"
        end
      when Hash
        object[index_or_key]
      else
        raise "Expected Array or Hash, not #{object.class}"
      end
    end

    # Assumes the underlying value is an `Array` or `Hash` and returns the element
    # at the given *index_or_key*, or `nil` if out of bounds or the key is missing.
    #
    # Raises if the underlying value is not an `Array` nor a `Hash`.
    def []?(index_or_key) : self?
      case object = @raw
      when Array
        if index_or_key.is_a?(Int)
          object[index_or_key]?
        else
          nil
        end
      when Hash
        object[index_or_key]?
      else
        raise "Expected Array or Hash, not #{object.class}"
      end
    end

    # Traverses the depth of a structure and returns the value.
    # Returns `nil` if not found.
    def dig?(index_or_key, *subkeys) : self?
      self[index_or_key]?.try &.dig?(*subkeys)
    end

    # :nodoc:
    def dig?(index_or_key) : self?
      case @raw
      when Hash, Array
        self[index_or_key]?
      else
        nil
      end
    end

    # Traverses the depth of a structure and returns the value, otherwise raises.
    def dig(index_or_key, *subkeys) : self
      self[index_or_key].dig(*subkeys)
    end

    # :nodoc:
    def dig(index_or_key) : self
      self[index_or_key]
    end

    def inspect(io : IO) : Nil
      @raw.inspect(io)
    end

    def to_s(io : IO) : Nil
      @raw.to_s(io)
    end

    # :nodoc:
    def pretty_print(pp)
      @raw.pretty_print(pp)
    end

    # Returns `true` if both `self` and *other*'s raw object are equal.
    def ==(other : self)
      raw == other.raw
    end

    # Returns `true` if the raw object is equal to *other*.
    def ==(other)
      raw == other
    end

    # See `Object#hash(hasher)`
    def_hash raw

    # Returns a new `{{ target_type }}` instance with the `raw` value `dup`ed.
    def dup
      self.class.new(raw.dup)
    end

    # Returns a new `{{ target_type }}` instance with the `raw` value `clone`ed.
    def clone
      self.class.new(raw.clone)
    end
  end
end
