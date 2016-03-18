# Object is the base type of all Crystal objects.
class Object
  # Boolean-negates this object.
  abstract def !

  # Returns true if this object is equal to `other`.
  #
  # Subclasses override this method to provide class-specific meaning.
  abstract def ==(other)

  # Returns true if this object is not equal to `other`.
  #
  # By default this method is implemented as `!(self == other)`
  # so there's no need to override this unless there's a more efficient
  # way to do it.
  def !=(other)
    !(self == other)
  end

  # Shortcut to `!(self =~ other)`
  def !~(other)
    !(self =~ other)
  end

  # Case equality.
  #
  # The `===` method is used in a `case ... when ... end` expression.
  #
  # For example, this code:
  #
  # ```
  # case value
  # when x
  #   # something when x
  # when y
  #   # something when y
  # end
  # ```
  #
  # Is equivalent to this code:
  #
  # ```
  # if x === value
  #   # something when x
  # elsif y === value
  #   # something when y
  # end
  # ```
  #
  # Object simply implements `===` by invoking `==`, but subclasses
  # (notably Regex) can override it to provide meaningful case-equality semantics.
  def ===(other)
    self == other
  end

  # Pattern match.
  #
  # Overridden by descendants (notably Regex and String) to provide meaningful
  # pattern-match semantics.
  def =~(other)
    nil
  end

  # Generates an `Int` hash value for this object.
  #
  # This method must have the property that `a == b` implies `a.hash == b.hash`.
  #
  # The hash value is used along with `==` by the `Hash` class to determine if two objects
  # reference the same hash key.
  abstract def hash

  # Returns a string representation of this object.
  #
  # Descendants must usually **not** override this method. Instead,
  # they must override `to_s(io)`, which must append to the given
  # IO object.
  def to_s
    String.build do |io|
      to_s io
    end
  end

  # Appends a String representation of this object
  # to the given IO object.
  #
  # An object must never append itself to the io argument,
  # as this will in turn call `to_s(io)` on it.
  abstract def to_s(io : IO)

  # Returns a `String` representation of this object.
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

  # Yields self to the block, and then returns self.
  #
  # The primary purpose of this method is to "tap into" a method chain,
  # in order to perform operations on intermediate results within the chain.
  #
  # ```
  # (1..10).tap { |x| puts "original: #{x.inspect}" }
  #        .to_a.tap { |x| puts "array: #{x.inspect}" }
  #             .select { |x| x % 2 == 0 }.tap { |x| puts "evens: #{x.inspect}" }
  #                                       .map { |x| x*x }.tap { |x| puts "squares: #{x.inspect}" }
  # ```
  def tap
    yield self
    self
  end

  # Yields self. Nil overrides this method and doesn't yield.
  #
  # This method is useful for dealing with nilable types, to safely
  # perform operations only when the value is not nil.
  #
  # ```
  # # First program argument in downcase, or nil
  # ARGV[0]?.try &.downcase
  # ```
  def try
    yield self
  end

  # Returns self. Nil overrides this method and raises an exception.
  def not_nil!
    self
  end

  # Return self.
  #
  # ```
  # str = "hello"
  # str.itself.object_id == str.object_id # => true
  # ```
  def itself
    self
  end

  # Returns a shallow copy of this object.
  #
  # Object returns self, but subclasses override this method to provide
  # specific dup behaviour.
  def dup
    self
  end

  # Returns a deep copy of this object.
  #
  # Object returns self, but subclasses override this method to provide
  # specific clone behaviour.
  def clone
    self
  end

  # Defines getter methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   getter name
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def name
  #     @name
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   getter :name, "age"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type.
  #
  # ```
  # class Person
  #   getter name : String
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   @name : String
  #
  #   def name
  #     @name
  #   end
  # end
  # ```
  macro getter(*names)
    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        @{{name.id}}
        {% name = name.var %}
      {% end %}

      def {{name.id}}
        @{{name.id}}
      end
    {% end %}
  end

  # Defines raise-on-nil and nilable getter methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   getter! name
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def name?
  #     @name
  #   end
  #
  #   def name
  #     @name.not_nil!
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   getter! :name, "age"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type, as nilable.
  #
  # ```
  # class Person
  #   getter! name : String
  # end
  # ```
  #
  # is the same as writing:
  #
  # ```
  # class Person
  #   @name : String?
  #
  #   def name?
  #     @name
  #   end
  #
  #   def name
  #     @name.not_nil!
  #   end
  # end
  # ```
  macro getter!(*names)
    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        @{{name}}?
        {% name = name.var %}
      {% end %}

      def {{name.id}}?
        @{{name.id}}
      end

      def {{name.id}}
        @{{name.id}}.not_nil!
      end
    {% end %}
  end

  # Defines query getter methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   getter? happy
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def happy?
  #     @happy
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   getter? :happy, "famous"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type.
  #
  # ```
  # class Person
  #   getter? happy : Bool
  # end
  # ```
  #
  # is the same as writing:
  #
  # ```
  # class Person
  #   @happy : Bool
  #
  #   def happy?
  #     @happy
  #   end
  # end
  # ```
  macro getter?(*names)
    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        @{{name}}
        {% name = name.var %}
      {% end %}

      def {{name.id}}?
        @{{name.id}}
      end
    {% end %}
  end

  # Defines setter methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   setter name
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def name=(@name)
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   setter :name, "age"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type.
  #
  # ```
  # class Person
  #   setter name : String
  # end
  # ```
  #
  # is the same as writing:
  #
  # ```
  # class Person
  #   @name : String
  #
  #   def name=(@name)
  #   end
  # end
  # ```
  macro setter(*names)
    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        @{{name}}
        def {{name.var.id}}=(@{{name.var.id}} : {{name.type}})
        end
      {% else %}
        def {{name.id}}=(@{{name.id}})
        end
      {% end %}
    {% end %}
  end

  # Defines property methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   property name
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def name=(@name)
  #   end
  #
  #   def name
  #     @name
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   property :name, "age"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type.
  #
  # ```
  # class Person
  #   property name : String
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   @name : String
  #
  #   def name=(@name)
  #   end
  #
  #   def name
  #     @name
  #   end
  # end
  # ```
  macro property(*names)
    getter {{*names}}
    setter {{*names}}
  end

  # Defines raise-on-nil property methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   property! name
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def name=(@name)
  #   end
  #
  #   def name?
  #     @name
  #   end
  #
  #   def name
  #     @name.not_nil!
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   property! :name, "age"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type, as nilable.
  #
  # ```
  # class Person
  #   property! name : String
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   @name : String?
  #
  #   def name=(@name)
  #   end
  #
  #   def name?
  #     @name
  #   end
  #
  #   def name
  #     @name.not_nil!
  #   end
  # end
  # ```
  macro property!(*names)
    getter! {{*names}}

    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        def {{name.var.id}}=(@{{name.var.id}} : {{name.type}})
        end
      {% else %}
        def {{name.id}}=(@{{name.id}})
        end
      {% end %}
    {% end %}
  end

  # Defines query property methods for each of the given arguments.
  #
  # Writing:
  #
  # ```
  # class Person
  #   property? happy
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   def happy=(@happy)
  #   end
  #
  #   def happy?
  #     @happy
  #   end
  # end
  # ```
  #
  # The arguments can be string literals, symbol literals or plain names:
  #
  # ```
  # class Person
  #   property? :happy, "famous"
  # end
  # ```
  #
  # If a type declaration is given, an instance variable with that name
  # is declared with that type.
  #
  # ```
  # class Person
  #   property? happy : Bool
  # end
  # ```
  #
  # Is the same as writing:
  #
  # ```
  # class Person
  #   @happy : Bool
  #
  #   def happy=(@happy)
  #   end
  #
  #   def happy?
  #     @happy
  #   end
  #
  #   def happy
  #     @happy.not_nil!
  #   end
  # end
  # ```
  macro property?(*names)
    getter? {{*names}}
    setter {{*names}}
  end

  # Delegate methods to to_object.
  #
  # Syntax is: delegate method1, [method2, ..., ], to_object
  #
  # Note that due to current language limitations this is only useful
  # when neither named arguments nor blocks are involved.
  #
  # ```
  # class StringWrapper
  #   def initialize(@string)
  #   end
  #
  #   delegate downcase, @string
  #   delegate gsub, @string
  #   delegate empty?, capitalize, @string
  # end
  #
  # wrapper = StringWrapper.new "HELLO"
  # wrapper.downcase       # => "hello"
  # wrapper.gsub(/E/, "A") # => "HALLO"
  # wrapper.empty?         # => false
  # wrapper.capitalize     # => "Hello"
  # ```
  macro delegate(method, *other_methods, to_object)
    def {{method.id}}(*args)
      {{to_object.id}}.{{method.id}}(*args)
    end

    {% for name, index in other_methods %}
      def {{name.id}}(*args)
        {{to_object.id}}.{{name.id}}(*args)
      end
    {% end %}
  end

  # Defines a `hash` method computed from the given fields.
  #
  # ```
  # class Person
  #   def initialize(@name, @age)
  #   end
  #
  #   # Define a hash method based on @name and @age
  #   def_hash @name, @age
  # end
  # ```
  macro def_hash(*fields)
    def hash
      {% if fields.size == 1 %}
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

  # Defines an `==` method by comparing the given fields.
  #
  # The generated `==` method has a self restriction.
  #
  # ```
  # class Person
  #   def initialize(@name, @age)
  #   end
  #
  #   # Define a `==` method that compares @name and @age
  #   def_equals @name, @age
  # end
  # ```
  macro def_equals(*fields)
    def ==(other : self)
      {% for field in fields %}
        return false unless {{field.id}} == other.{{field.id}}
      {% end %}
      true
    end
  end

  # Defines `hash` and `==` method from the given fields.
  #
  # The generated `==` method has a self restriction.
  #
  # ```
  # class Person
  #   def initialize(@name, @age)
  #   end
  #
  #   # Define a hash method based on @name and @age
  #   # Define a `==` method that compares @name and @age
  #   def_equals_and_hash @name, @age
  # end
  # ```
  macro def_equals_and_hash(*fields)
    def_equals {{*fields}}
    def_hash {{*fields}}
  end

  # Forwards missing methods to delegate.
  # ```
  # class StringWrapper
  #   def initialize(@string)
  #   end
  #
  #   forward_missing_to @string
  # end
  #
  # wrapper = StringWrapper.new "HELLO"
  # wrapper.downcase       # => "hello"
  # wrapper.gsub(/E/, "A") # => "HALLO"
  # ```
  macro forward_missing_to(delegate)
    macro method_missing(name, args, block)
      {{delegate}}.\{{name.id}}(\{{*args}}) \{{block}}
    end
  end
end
