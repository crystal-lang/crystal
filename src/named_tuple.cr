# A named tuple is a fixed-size, immutable, stack-allocated mapping
# of a fixed set of keys to values.
#
# You can think of a `NamedTuple` as an immutable `Hash` whose keys (which
# are of type `Symbol`), and the types for each key, are known at compile time.
#
# A named tuple can be created with a named tuple literal:
#
# ```
# language = {name: "Crystal", year: 2011} # NamedTuple(name: String, year: Int32)
#
# language[:name]  # => "Crystal"
# language[:year]  # => 2011
# language[:other] # compile time error
# ```
#
# The compiler knows what types are in each key, so when indexing a named tuple
# with a symbol literal the compiler will return the value for that key and
# with the expected type, like in the above snippet. Indexing with a symbol
# literal for which there's no key will give a compile-time error.
#
# Indexing with a symbol that is only known at runtime will return
# a value whose type is the union of all the types in the named tuple,
# and might raise `KeyError`.
struct NamedTuple
  # Creates a named tuple that will contain the given arguments.
  #
  # This method is useful in macros and generic code because with it you can
  # creates empty named tuples, something that you can't do with a tuple literal.
  #
  # ```
  # NamedTuple.new(name: "Crystal", year: 2011) #=> {name: "Crystal", year: 2011}
  # NamedTuple.new # => {}
  # {}             # syntax error
  # ```
  def self.new(**options : **T)
    options
  end

  # Creates a named tuple from the given hash, with elements casted to the given types.
  # Here the Int32 | String union is cast to Int32.
  #
  # ```
  # num_or_str = 42.as(Int32 | String)
  # NamedTuple(name: String, val: Int32).from({"name" => "number", "val" => num_or_str}) # => {name: "number", val: 42}
  #
  # num_or_str = "a string".as(Int32 | String)
  # NamedTuple(name: String, val: Int32).from({"name" => "number", "val" => num_or_str}) # raises TypeCastError (cast from String to Int32 failed)
  # ```
  # See also: `#from`.
  def self.from(hash : Hash) : self
    {% begin %}
    NamedTuple.new(**{{T}}).from(hash)
    {% end %}
  end

  # Expects to be called on a named tuple whose values are types, creates a tuple from the given hash,
  # with types casted appropriately. The hash keys must be either symbols or strings.
  #
  # This allows you to easily pass a hash as individual named arguments to a method.
  #
  # ```
  # require "json"
  #
  # def speak_about(thing : String, n : Int64)
  #   "I see #{n} #{thing}s"
  # end
  #
  # data = JSON.parse(%({"thing": "world", "n": 2})).as_h
  # speak_about(**{thing: String, n: Int64}.from(data)) # => "I see 2 worlds"
  # ```
  def from(hash : Hash)
    if size != hash.size
      raise ArgumentError.new("Expected a hash with #{size} keys but one with #{hash.size} keys was given.")
    end

    {% begin %}
      NamedTuple.new(
      {% for key, value in T %}
        {{key.stringify}}: self[{{key.symbolize}}].cast(hash.fetch({{key.symbolize}}) { hash["{{key}}"] }),
      {% end %}
      )
    {% end %}
  end

  # Returns the value for the given *key*, if there's such key, otherwise raises `KeyError`.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  #
  # key = :name
  # tuple[key] # => "Crystal"
  #
  # key = "year"
  # tuple[key] # => 2011
  #
  # key = :other
  # tuple[key] # raises KeyError
  # ```
  def [](key : Symbol | String)
    fetch(key) { raise KeyError.new "Missing named tuple key: #{key.inspect}" }
  end

  # Returns the value for the given *key*, if there's such key, otherwise returns `nil`.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  #
  # key = :name
  # tuple[key]? # => "Crystal"
  #
  # key = "year"
  # tuple[key] # => 2011
  #
  # key = :other
  # tuple[key]? # => nil
  # ```
  def []?(key : Symbol | String)
    fetch(key, nil)
  end

  # Returns the value for the given *key*, if there's such key, otherwise returns *default_value*.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.fetch(:name, "Unknown") # => "Crystal"
  # tuple.fetch("year", 0)        # => 2011
  # tuple.fetch(:other, 0)        # => 0
  # ```
  def fetch(key : Symbol | String, default_value)
    fetch(key) { default_value }
  end

  # Returns the value for the given *key*, if there's such key, otherwise the value returned by the block.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.fetch(:name) { "Unknown" } # => "Crystal"
  # tuple.fetch(:other) { 0 }        # => 0
  # ```
  def fetch(key : Symbol, &block)
    {% for key in T %}
      return self[{{key.symbolize}}] if {{key.symbolize}} == key
    {% end %}
    yield
  end

  # Returns the value for the given *key*, if there's such key, otherwise the value returned by the block.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.fetch("name") { "Unknown" } # => "Crystal"
  # tuple.fetch("other") { 0 }        # => 0
  # ```
  def fetch(key : String, &block)
    {% for key in T %}
      return self[{{key.symbolize}}] if {{key.stringify}} == key
    {% end %}
    yield
  end

  # Merges two named tuples into one, returning a new named tuple.
  # If a key is defined in both tuples, the value and its type is used from *other*.
  #
  # ```
  # a = {foo: "Hello", bar: "Old"}
  # b = {bar: "New", baz: "Bye"}
  # a.merge(b) # => {foo: "Hello", bar: "New", baz: "Bye"}
  # ```
  def merge(other : NamedTuple)
    merge(**other)
  end

  # ditto
  def merge(**other : **U) forall U
    {% begin %}
    {
      {% for k in T %} {% unless U.keys.includes?(k) %} {{k.stringify}}: self[{{k.symbolize}}],{% end %} {% end %}
      {% for k in U %} {{k.stringify}}: other[{{k.symbolize}}], {% end %}
    }
    {% end %}
  end

  # Returns a hash value based on this name tuple's size, keys and values.
  #
  # See also: `Object#hash`.
  # See `Object#hash(hasher)`
  def hash(hasher)
    {% for key in T.keys.sort %}
      hasher = {{key.symbolize}}.hash(hasher)
      hasher = self[{{key.symbolize}}].hash(hasher)
    {% end %}
    hasher
  end

  # Returns the types of this named tuple type.
  #
  # ```
  # tuple = {a: 1, b: "hello", c: 'x'}
  # tuple.class.types # => {a: Int32, b: String, c: Char}
  # ```
  def self.types
    NamedTuple.new(**{{T}})
  end

  # Same as `to_s`.
  def inspect
    to_s
  end

  # Returns a `Tuple` of symbols with the keys in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.keys # => {:name, :year}
  # ```
  def keys
    {% begin %}
      Tuple.new(
        {% for key in T %}
          {{key.symbolize}},
        {% end %}
      )
    {% end %}
  end

  protected def sorted_keys
    {% begin %}
      Tuple.new(
        {% for key in T.keys.sort %}
          {{key.symbolize}},
        {% end %}
      )
    {% end %}
  end

  # Returns a `Tuple` with the values in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.values # => {"Crystal", 2011}
  # ```
  def values
    {% begin %}
      Tuple.new(
        {% for key in T %}
          self[{{key.symbolize}}],
        {% end %}
      )
    {% end %}
  end

  # Returns `true` if this named tuple has the given *key*, `false` otherwise.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.has_key?(:name)  # => true
  # tuple.has_key?(:other) # => false
  # ```
  def has_key?(key : Symbol) : Bool
    {% for key in T %}
      return true if {{key.symbolize}} == key
    {% end %}
    false
  end

  # ditto
  def has_key?(key : String) : Bool
    {% for key in T %}
      return true if {{key.stringify}} == key
    {% end %}
    false
  end

  # Appends a string representation of this named tuple to the given `IO`.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.to_s # => %({name: "Crystal", year: 2011})
  # ```
  def to_s(io)
    io << "{"
    {% for key, value, i in T %}
      {% if i > 0 %}
        io << ", "
      {% end %}
      key = {{key.stringify}}
      if Symbol.needs_quotes?(key)
        key.inspect(io)
      else
        io << key
      end
      io << ": "
      self[{{key.symbolize}}].inspect(io)
    {% end %}
    io << "}"
  end

  def pretty_print(pp)
    pp.surround("{", "}", left_break: nil, right_break: nil) do
      {% for key, value, i in T %}
        {% if i > 0 %}
          pp.comma
        {% end %}
        pp.group do
          key = {{key.stringify}}
          if Symbol.needs_quotes?(key)
            pp.text key.inspect
          else
            pp.text key
          end
          pp.text ": "
          pp.nest do
            pp.breakable ""
            self[{{key.symbolize}}].pretty_print(pp)
          end
        end
      {% end %}
    end
  end

  # Yields each key and value in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.each do |key, value|
  #   puts "#{key} = #{value}"
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # name = Crystal
  # year = 2011
  # ```
  def each : Nil
    {% for key in T %}
      yield {{key.symbolize}}, self[{{key.symbolize}}]
    {% end %}
  end

  # Yields each key in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.each_key do |key|
  #   puts key
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # name
  # year
  # ```
  def each_key : Nil
    {% for key in T %}
      yield {{key.symbolize}}
    {% end %}
  end

  # Yields each value in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.each_value do |value|
  #   puts value
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # Crystal
  # 2011
  # ```
  def each_value : Nil
    {% for key in T %}
      yield self[{{key.symbolize}}]
    {% end %}
  end

  # Yields each key and value, together with an index starting at *offset*, in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.each_with_index do |key, value, i|
  #   puts "#{i + 1}) #{key} = #{value}"
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 1) name = Crystal
  # 2) year = 2011
  # ```
  def each_with_index(offset = 0)
    i = offset
    each do |key, value|
      yield key, value, i
      i += 1
    end
  end

  # Returns an `Array` populated with the results of each iteration in the given block,
  # which is given each key and value in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.map { |k, v| "#{k}: #{v}" } # => ["name: Crystal", "year: 2011"]
  # ```
  def map
    array = Array(typeof(yield first_key_internal, first_value_internal)).new(size)
    each do |k, v|
      array.push yield k, v
    end
    array
  end

  # Returns a new `Array` of tuples populated with each key-value pair.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.to_a # => [{:name, "Crystal"}, {:year, 2011}]
  # ```
  def to_a
    ary = Array({typeof(first_key_internal), typeof(first_value_internal)}).new(size)
    each do |key, value|
      ary << {key.as(typeof(first_key_internal)), value.as(typeof(first_value_internal))}
    end
    ary
  end

  # Returns a `Hash` with the keys and values in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.to_h # => {:name => "Crystal", :year => 2011}
  # ```
  def to_h
    {% if T.size == 0 %}
      {% raise "Can't convert an empty NamedTuple to a Hash" %}
    {% else %}
      {
        {% for key in T %}
          {{key.symbolize}} => self[{{key.symbolize}}],
        {% end %}
      }
    {% end %}
  end

  # Returns the number of elements in this named tuple.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.size # => 2
  # ```
  def size
    {{T.size}}
  end

  # Returns `true` if this named tuple is empty.
  #
  # ```
  # tuple = {name: "Crystal", year: 2011}
  # tuple.empty? # => false
  # ```
  def empty?
    size == 0
  end

  # Returns `true` if this tuple has the same keys as *other*, and values
  # for each key are the same in `self` and *other*.
  #
  # ```
  # tuple1 = {name: "Crystal", year: 2011}
  # tuple2 = {year: 2011, name: "Crystal"}
  # tuple3 = {name: "Crystal", year: 2012}
  # tuple4 = {name: "Crystal", year: 2011.0}
  #
  # tuple1 == tuple2 # => true
  # tuple1 == tuple3 # => false
  # tuple1 == tuple4 # => true
  # ```
  def ==(other : self)
    {% for key in T %}
      return false unless self[{{key.symbolize}}] == other[{{key.symbolize}}]
    {% end %}
    true
  end

  # ditto
  def ==(other : NamedTuple)
    return false unless sorted_keys == other.sorted_keys

    {% for key in T %}
      return false unless self[{{key.symbolize}}] == other[{{key.symbolize}}]?
    {% end %}

    return true
  end

  # Returns a named tuple with the same keys but with cloned values, using the `clone` method.
  def clone
    {% begin %}
      {
        {% for key in T %}
          {{key.stringify}}: self[{{key.symbolize}}].clone,
        {% end %}
      }
    {% end %}
  end

  private def first_key_internal
    i = 0
    keys[i]
  end

  private def first_value_internal
    i = 0
    values[i]
  end
end
