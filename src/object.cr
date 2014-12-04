class Object
  def !=(other)
    !(self == other)
  end

  def ===(other)
    self == other
  end

  def =~(other)
    nil
  end

  # Returns a string representation of this object.
  #
  # Classes must usually **not** override this method. Instead,
  # they must override `to_s(io)`, which must append to the given
  # IO object.
  def to_s
    String.build do |io|
      to_s io
    end
  end

  # Appends a string representation of this object
  # to the given IO object.
  #
  # An object must never append itself to the `io` argument,
  # as this will in turn call `to_s(io)` on it.
  abstract def to_s(io : IO)

  # Returns a String representation of this object.
  #
  # Similar to `to_s`, but usually returns more information about
  # this object.
  #
  # Classes must usually **not** override this method. Instead,
  # they must override `inspect(io)`, which must append to the
  # given IO object.
  def inspect
    String.build do |io|
      inspect io
    end
  end

  # Appends a string representation of this object
  # to the given IO object.
  #
  # Similar to `to_s(io)`, but usually appends more information
  # about this object.
  def inspect(io : IO)
    to_s io
  end

  def tap
    yield self
    self
  end

  def try
    yield self
  end

  def not_nil!
    self
  end

  def itself
    self
  end

  macro getter(*names)
    {% for name in names %}
      {% name = name.var if name.is_a?(DeclareVar) %}

      def {{name.id}}
        @{{name.id}}
      end
    {% end %}
  end

  macro getter!(*names)
    {% for name in names %}
      {% name = name.var if name.is_a?(DeclareVar) %}

      def {{name.id}}?
        @{{name.id}}
      end

      def {{name.id}}
        @{{name.id}}.not_nil!
      end
    {% end %}
  end

  macro getter?(*names)
    {% for name in names %}
      {% name = name.var if name.is_a?(DeclareVar) %}

      def {{name.id}}?
        @{{name.id}}
      end
    {% end %}
  end

  macro setter(*names)
    {% for name in names %}
      {% if name.is_a?(DeclareVar) %}
        def {{name.var.id}}=(@{{name.var.id}} : {{name.type}})
        end
      {% else %}
        def {{name.id}}=(@{{name.id}})
        end
      {% end %}
    {% end %}
  end

  macro property(*names)
    getter {{*names}}
    setter {{*names}}
  end

  macro property!(*names)
    getter! {{*names}}
    setter {{*names}}
  end

  macro property?(*names)
    getter? {{*names}}
    setter {{*names}}
  end

  macro delegate(method, to)
    def {{method.id}}(*args)
      {{to.id}}.{{method.id}}(*args)
    end
  end

  macro def_hash(*fields)
    def hash
      {% if fields.length == 1 %}
        {{fields[0]}}.hash
      {% else %}
        hash = 0
        {% for field in fields %}
          hash = 31 * hash + {{field}}.hash
        {% end %}
        hash
      {% end %}
    end
  end

  macro def_equals(*fields)
    def ==(other : self)
      {% for field in fields %}
        return false unless {{field.id}} == other.{{field.id}}
      {% end %}
      true
    end
  end

  macro def_equals_and_hash(*fields)
    def_equals {{*fields}}
    def_hash {{*fields}}
  end

  macro forward_missing_to(delegate)
    macro method_missing(name, args, block)
      @hash.\{{name.id}}(\{{*args}}) \{{block}}
    end
  end

  macro alias_method(new_method, old_method)
    def {{new_method.id}}(*args)
      {{old_method.id}}(*args)
    end
  end
end
