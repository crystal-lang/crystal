require "./encoding"

class URI
  # An ordered multi-value mapped collection representing generic URI parameters.
  struct Params
    include Enumerable({String, String})

    # Parses an URI query string into a `URI::Params`
    #
    # ```
    # require "uri/params"
    #
    # URI::Params.parse("foo=bar&foo=baz&qux=zoo")
    # # => #<URI::Params @raw_params = {"foo" => ["bar", "baz"], "qux" => ["zoo"]}>
    # ```
    def self.parse(query : String) : self
      parsed = {} of String => Array(String)
      parse(query) do |key, value|
        parsed.put_if_absent(key) { [] of String } << value
      end
      Params.new(parsed)
    end

    # Parses an URI query and yields each key-value pair.
    #
    # ```
    # require "uri/params"
    #
    # query = "foo=bar&foo=baz&qux=zoo"
    # URI::Params.parse(query) do |key, value|
    #   # ...
    # end
    # ```
    def self.parse(query : String, &)
      return if query.empty?

      key = nil
      buffer = IO::Memory.new

      i = 0
      first_equal = true
      bytesize = query.bytesize
      while i < bytesize
        byte = query.to_unsafe[i]
        char = byte.unsafe_chr

        case char
        when '='
          if first_equal
            key = buffer.to_s
            buffer.clear
            i += 1
            first_equal = false
          else
            i = decode_one_www_form_component query, bytesize, i, byte, char, buffer
          end
        when '&', ';'
          value = buffer.to_s
          buffer.clear

          if key
            yield key.not_nil!, value
          else
            yield value, "" unless value.empty?
          end

          key = nil
          first_equal = true
          i += 1
        else
          i = decode_one_www_form_component query, bytesize, i, byte, char, buffer
        end
      end

      if key
        yield key.not_nil!, buffer.to_s
      else
        yield buffer.to_s, "" unless buffer.empty?
      end
    end

    # Returns the given key value pairs as a url-encoded URI form/query.
    #
    # ```
    # require "uri/params"
    #
    # URI::Params.encode({"foo" => "bar", "baz" => ["quux", "quuz"]}) # => "foo=bar&baz=quux&baz=quuz"
    # ```
    def self.encode(hash : Hash(String, String | Array(String))) : String
      build do |builder|
        hash.each do |key, value|
          builder.add key, value
        end
      end
    end

    # Appends the given key value pairs as a url-encoded URI form/query to the given `io`.
    #
    # ```
    # require "uri/params"
    #
    # io = IO::Memory.new
    # URI::Params.encode(io, {"foo" => "bar", "baz" => ["quux", "quuz"]})
    # io.to_s # => "foo=bar&baz=quux&baz=quuz"
    # ```
    def self.encode(io : IO, hash : Hash(String, String | Array(String))) : Nil
      build(io) do |builder|
        hash.each do |key, value|
          builder.add key, value
        end
      end
    end

    # Returns the given key value pairs as a url-encoded URI form/query.
    #
    # ```
    # require "uri/params"
    #
    # URI::Params.encode({foo: "bar", baz: ["quux", "quuz"]}) # => "foo=bar&baz=quux&baz=quuz"
    # ```
    def self.encode(named_tuple : NamedTuple) : String
      build do |builder|
        named_tuple.each do |key, value|
          builder.add key.to_s, value
        end
      end
    end

    # Appends the given key value pairs as a url-encoded URI form/query to the given `io`.
    #
    # ```
    # require "uri/params"
    #
    # io = IO::Memory.new
    # URI::Params.encode(io, {foo: "bar", baz: ["quux", "quuz"]})
    # io.to_s # => "foo=bar&baz=quux&baz=quuz"
    # ```
    def self.encode(io : IO, named_tuple : NamedTuple) : Nil
      build(io) do |builder|
        named_tuple.each do |key, value|
          builder.add key.to_s, value
        end
      end
    end

    # Builds an url-encoded URI form/query.
    #
    # The yielded object has an `add` method that accepts two arguments,
    # a key (`String`) and a value (`String` or `Nil`).
    # Keys and values are escaped using `URI.encode_www_form`.
    #
    # ```
    # require "uri/params"
    #
    # params = URI::Params.build do |form|
    #   form.add "color", "black"
    #   form.add "name", "crystal"
    #   form.add "year", "2012 - today"
    # end
    # params # => "color=black&name=crystal&year=2012+-+today"
    # ```
    #
    # By default spaces are outputted as `+`.
    # If *space_to_plus* is `false` then they are outputted as `%20`:
    #
    # ```
    # require "uri/params"
    #
    # params = URI::Params.build(space_to_plus: false) do |form|
    #   form.add "year", "2012 - today"
    # end
    # params # => "year=2012%20-%20today"
    # ```
    def self.build(*, space_to_plus : Bool = true, &block : Builder ->) : String
      String.build do |io|
        yield Builder.new(io, space_to_plus: space_to_plus)
      end
    end

    # :ditto:
    def self.build(io : IO, *, space_to_plus : Bool = true, & : Builder ->) : Nil
      yield Builder.new(io, space_to_plus: space_to_plus)
    end

    protected getter raw_params

    # Returns an empty `URI::Params`.
    def initialize
      @raw_params = {} of String => Array(String)
    end

    def initialize(@raw_params : Hash(String, Array(String)))
    end

    def_equals_and_hash @raw_params

    # Returns a copy of this `URI::Params` instance.
    #
    # ```
    # require "uri/params"
    #
    # original = URI::Params{"name" => "Jamie"}
    # updated = original.dup
    # updated["name"] = "Ary"
    #
    # original["name"] # => "Jamie"
    # ```
    #
    # Identical to `#clone`.
    def dup : self
      # Since the component types (keys and values) are immutable, there's no
      # difference between deep and shallow copy, so we can just use `clone`
      # here.
      clone
    end

    # Returns a copy of this `URI::Params` instance.
    #
    # ```
    # require "uri/params"
    #
    # original = URI::Params{"name" => "Jamie"}
    # updated = original.clone
    # updated["name"] = "Ary"
    #
    # original["name"] # => "Jamie"
    # ```
    #
    # Identical to `#dup`.
    def clone : self
      self.class.new(raw_params.clone)
    end

    # Returns first value for specified param name.
    #
    # ```
    # require "uri/params"
    #
    # params = URI::Params.parse("email=john@example.org")
    # params["email"]              # => "john@example.org"
    # params["non_existent_param"] # KeyError
    # ```
    def [](name) : String
      fetch(name) { raise KeyError.new "Missing param name: #{name.inspect}" }
    end

    # Returns first value or `nil` for specified param *name*.
    #
    # ```
    # params["email"]?              # => "john@example.org"
    # params["non_existent_param"]? # nil
    # ```
    def []?(name) : String?
      fetch(name, nil)
    end

    # Returns `true` if param with provided name exists.
    #
    # ```
    # params.has_key?("email")   # => true
    # params.has_key?("garbage") # => false
    # ```
    delegate has_key?, to: raw_params

    # Returns `true` if params is empty.
    #
    # ```
    # URI::Params.new.empty?                              # => true
    # URI::Params.parse("foo=bar&foo=baz&qux=zoo").empty? # => false
    # ```
    delegate empty?, to: raw_params

    # Sets the *name* key to *value*.
    #
    # ```
    # require "uri/params"
    #
    # params = URI::Params{"a" => ["b", "c"]}
    # params["a"] = "d"
    # params["a"]           # => "d"
    # params.fetch_all("a") # => ["d"]
    #
    # params["a"] = ["e", "f"]
    # params["a"]           # => "e"
    # params.fetch_all("a") # => ["e", "f"]
    # ```
    def []=(name, value : String | Array(String))
      raw_params[name] =
        case value
        in String        then [value]
        in Array(String) then value
        end
    end

    # Returns all values for specified param *name*.
    #
    # ```
    # params.set_all("item", ["pencil", "book", "workbook"])
    # params.fetch_all("item") # => ["pencil", "book", "workbook"]
    # ```
    def fetch_all(name) : Array(String)
      raw_params.fetch(name) { [] of String }
    end

    # Returns first value for specified param *name*. Falls back to provided
    # *default* value when there is no such param.
    #
    # ```
    # params["email"] = "john@example.org"
    # params.fetch("email", "none@example.org")           # => "john@example.org"
    # params.fetch("non_existent_param", "default value") # => "default value"
    # ```
    def fetch(name, default)
      fetch(name) { default }
    end

    # Returns first value for specified param *name*. Falls back to return value
    # of provided block when there is no such param.
    #
    # ```
    # params.delete("email")
    # params.fetch("email") { raise "Email is missing" }              # raises "Email is missing"
    # params.fetch("non_existent_param") { "default computed value" } # => "default computed value"
    # ```
    def fetch(name, &)
      return yield name unless has_key?(name)
      raw_params[name].first
    end

    # Appends new value for specified param *name*.
    # Creates param when there was no such param.
    #
    # ```
    # params.add("item", "keychain")
    # params.fetch_all("item") # => ["pencil", "book", "workbook", "keychain"]
    # ```
    def add(name, value)
      params = raw_params.put_if_absent(name) { [] of String }
      params.clear if params.size == 1 && params[0] == ""
      params << value
    end

    # Sets all *values* for specified param *name* at once.
    #
    # ```
    # params.set_all("item", ["keychain", "keynote"])
    # params.fetch_all("item") # => ["keychain", "keynote"]
    # ```
    def set_all(name, values)
      raw_params[name] = values
    end

    # Allows to iterate over all name-value pairs.
    #
    # ```
    # params.each do |name, value|
    #   puts "#{name} => #{value}"
    # end
    #
    # # Outputs:
    # # email => john@example.org
    # # item => keychain
    # # item => keynote
    # ```
    def each(&)
      raw_params.each do |name, values|
        values.each do |value|
          yield({name, value})
        end
      end
    end

    # Deletes first value for provided param *name*. If there are no values left,
    # deletes param itself. Returns deleted value.
    #
    # ```
    # params.delete("item")    # => "keychain"
    # params.fetch_all("item") # => ["keynote"]
    #
    # params.delete("item") # => "keynote"
    # params["item"]        # KeyError
    #
    # params.delete("non_existent_param") # KeyError
    # ```
    def delete(name) : String
      value = raw_params[name].shift
      raw_params.delete(name) if raw_params[name].size == 0
      value
    end

    # Deletes all values for provided param *name*. Returns array of deleted
    # values.
    #
    # ```
    # params.set_all("comments", ["hello, world!", ":+1:"])
    # params.delete_all("comments") # => ["hello, world!", ":+1:"]
    # params.has_key?("comments")   # => false
    # ```
    def delete_all(name) : Array(String)?
      raw_params.delete(name)
    end

    # Merges *params* into self.
    #
    # ```
    # params = URI::Params.parse("foo=bar&foo=baz&qux=zoo")
    # other_params = URI::Params.parse("foo=buzz&foo=extra")
    # params.merge!(other_params).to_s # => "foo=buzz&foo=extra&qux=zoo"
    # params.fetch_all("foo")          # => ["buzz", "extra"]
    # ```
    #
    # See `#merge` for a non-mutating alternative
    def merge!(params : URI::Params, *, replace : Bool = true) : URI::Params
      if replace
        @raw_params.merge!(params.raw_params) { |_, _first, second| second.dup }
      else
        @raw_params.merge!(params.raw_params) do |_, first, second|
          first + second
        end
      end

      self
    end

    # Merges *params* and self into a new instance.
    # If *replace* is `false` values with the same key are concatenated.
    # Otherwise the value in *params* overrides the one in self.
    #
    # ```
    # params = URI::Params.parse("foo=bar&foo=baz&qux=zoo")
    # other_params = URI::Params.parse("foo=buzz&foo=extra")
    # params.merge(other_params).to_s                 # => "foo=buzz&foo=extra&qux=zoo"
    # params.merge(other_params, replace: false).to_s # => "foo=bar&foo=baz&foo=buzz&foo=extra&qux=zoo"
    # ```
    #
    # See `#merge!` for a mutating alternative
    def merge(params : URI::Params, *, replace : Bool = true) : URI::Params
      dup.merge!(params, replace: replace)
    end

    # Serializes to string representation as http url-encoded form.
    #
    # ```
    # require "uri/params"
    #
    # params = URI::Params.parse("item=keychain&greeting=hello+world&email=john@example.org")
    # params.to_s # => "item=keychain&greeting=hello+world&email=john%40example.org"
    # ```
    #
    # By default spaces are outputted as `+`.
    # If *space_to_plus* is `false` then they are outputted as `%20`:
    #
    # ```
    # require "uri/params"
    #
    # params = URI::Params.parse("item=keychain&greeting=hello+world&email=john@example.org")
    # params.to_s(space_to_plus: false) # => "item=keychain&greeting=hello%20world&email=john%40example.org"
    # ```
    def to_s(*, space_to_plus : Bool = true)
      String.build do |io|
        to_s(io, space_to_plus: space_to_plus)
      end
    end

    # :ditto:
    def to_s(io : IO, *, space_to_plus : Bool = true) : Nil
      builder = Builder.new(io, space_to_plus: space_to_plus)
      each do |name, value|
        builder.add(name, value)
      end
    end

    def inspect(io : IO)
      io << "URI::Params"
      @raw_params.inspect(io)
    end

    # :nodoc:
    def self.decode_one_www_form_component(query, bytesize, i, byte, char, buffer)
      URI.decode_one query, bytesize, i, byte, char, buffer, true
    end

    # URI params builder.
    #
    # Every parameter added is directly written to an `IO`,
    # where keys and values are properly escaped.
    class Builder
      # Initializes this builder to write to the given *io*.
      # `space_to_plus` controls how spaces are encoded:
      # - if `true` (the default) they are converted to `+`
      # - if `false` they are converted to `%20`
      def initialize(@io : IO, *, @space_to_plus : Bool = true)
        @first = true
      end

      # Adds a key-value pair to the params being built.
      def add(key, value : String?)
        @io << '&' unless @first
        @first = false
        URI.encode_www_form key, @io, space_to_plus: @space_to_plus
        @io << '='
        URI.encode_www_form value, @io, space_to_plus: @space_to_plus if value
        self
      end

      # Adds all of the given *values* as key-value pairs to the params being built.
      def add(key, values : Array)
        values.each { |value| add(key, value) }
        self
      end
    end
  end
end
