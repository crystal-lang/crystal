require "uri"

module HTTP
  # Represents a collection of http parameters and their respective values.
  struct Params
    include Enumerable({String, String})

    # Parses an HTTP query string into a `HTTP::Params`
    #
    # ```
    # HTTP::Params.parse("foo=bar&foo=baz&qux=zoo")
    # # => #<HTTP::Params @raw_params = {"foo" => ["bar", "baz"], "qux" => ["zoo"]}>
    # ```
    def self.parse(query : String) : self
      parsed = {} of String => Array(String)
      parse(query) do |key, value|
        ary = parsed[key] ||= [] of String
        ary.push value
      end
      Params.new(parsed)
    end

    # Parses an HTTP query and yields each key-value pair.
    #
    # ```
    # query = "foo=bar&foo=baz&qux=zoo"
    # HTTP::Params.parse(query) do |key, value|
    #   # ...
    # end
    # ```
    def self.parse(query : String)
      return if query.empty?

      key = nil
      buffer = IO::Memory.new

      i = 0
      first_equal = true
      bytesize = query.bytesize
      while i < bytesize
        byte = query.unsafe_byte_at(i)
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

    # Returns the given key value pairs as a url-encoded HTTP form/query.
    #
    # ```
    # HTTP::Params.encode({"foo" => "bar", "baz" => "qux"}) # => foo=bar&baz=qux
    # ```
    def self.encode(hash : Hash(String, String))
      build do |builder|
        hash.each do |key, value|
          builder.add key, value
        end
      end
    end

    # Returns the given key value pairs as a url-encoded HTTP form/query.
    #
    # ```
    # HTTP::Params.encode({foo: "bar", baz: "qux"}) # => foo=bar&baz=qux
    # ```
    def self.encode(named_tuple : NamedTuple)
      build do |builder|
        named_tuple.each do |key, value|
          builder.add key.to_s, value
        end
      end
    end

    # Builds an url-encoded HTTP form/query.
    #
    # The yielded object has an `add` method that accepts two arguments,
    # a key (`String`) and a value (`String` or `Nil`).
    # Keys and values are escaped using `URI#escape`.
    #
    # ```
    # params = HTTP::Params.build do |form|
    #   form.add "color", "black"
    #   form.add "name", "crystal"
    #   form.add "year", "2012 - today"
    # end
    # params # => "color=black&name=crystal&year=2012+-+today"
    # ```
    def self.build(&block : Builder ->) : String
      form_builder = Builder.new
      yield form_builder
      form_builder.to_s
    end

    protected getter raw_params

    def initialize(@raw_params : Hash(String, Array(String)))
    end

    def ==(other : self)
      self.raw_params == other.raw_params
    end

    def ==(other)
      false
    end

    # Returns first value for specified param name.
    #
    # ```
    # params = HTTP::Params.parse("email=john@example.org")
    # params["email"]              # => "john@example.org"
    # params["non_existent_param"] # KeyError
    # ```
    def [](name)
      raw_params[name].first
    end

    # Returns first value or `nil` for specified param *name*.
    #
    # ```
    # params["email"]?              # => "john@example.org"
    # params["non_existent_param"]? # nil
    # ```
    def []?(name)
      fetch(name) { nil }
    end

    # Returns `true` if param with provided name exists.
    #
    # ```
    # params.has_key?("email")   # => true
    # params.has_key?("garbage") # => false
    # ```
    delegate has_key?, to: raw_params

    # Sets first *value* for specified param *name*.
    #
    # ```
    # params["item"] = "pencil"
    # ```
    def []=(name, value)
      raw_params[name] ||= [""]
      raw_params[name][0] = value
    end

    # Returns all values for specified param *name*.
    #
    # ```
    # params.set_all("item", ["pencil", "book", "workbook"])
    # params.fetch_all("item") # => ["pencil", "book", "workbook"]
    # ```
    def fetch_all(name)
      raw_params.fetch(name) { [] of String }
    end

    # Returns first value for specified param *name*.
    #
    # ```
    # params.fetch("email")              # => "john@example.org"
    # params.fetch("non_existent_param") # KeyError
    # ```
    def fetch(name)
      raw_params.fetch(name).first
    end

    # Returns first value for specified param *name*. Fallbacks to provided
    # *default* value when there is no such param.
    #
    # ```
    # params.fetch("email", "none@example.org")           # => "john@example.org"
    # params.fetch("non_existent_param", "default value") # => "default value"
    # ```
    def fetch(name, default)
      return default unless has_key?(name)
      fetch(name)
    end

    # Returns first value for specified param *name*. Fallbacks to return value
    # of provided block when there is no such param.
    #
    # ```
    # params.fetch("email") { raise "Email is missing" }              # raises "Email is missing"
    # params.fetch("non_existent_param") { "default computed value" } # => "default computed value"
    # ```
    def fetch(name)
      return yield unless has_key?(name)
      fetch(name)
    end

    # Appends new value for specified param *name*.
    # Creates param when there was no such param.
    #
    # ```
    # params.add("item", "keychain")
    # params.fetch_all("item") # => ["pencil", "book", "workbook", "keychain"]
    # ```
    def add(name, value)
      raw_params[name] ||= [] of String
      raw_params[name] = [] of String if raw_params[name] == [""]
      raw_params[name] << value
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
    def each
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
    def delete(name)
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
    def delete_all(name)
      raw_params.delete(name)
    end

    # Serializes to string representation as http url-encoded form.
    #
    # ```
    # params = HTTP::Params.parse("item=keychain&item=keynote&email=john@example.org")
    # params.to_s # => "item=keychain&item=keynote&email=john%40example.org"
    # ```
    # TODO: `to_s` should escape @ to %40 ?
    def to_s(io)
      builder = Builder.new(io)
      each do |name, value|
        builder.add(name, value)
      end
    end

    # :nodoc:
    def self.encode_www_form_component(string : String, io : IO)
      URI.escape(string, io, true)
    end

    # :nodoc:
    def self.decode_one_www_form_component(query, bytesize, i, byte, char, buffer)
      URI.unescape_one query, bytesize, i, byte, char, buffer, true
    end

    # HTTP params builder.
    #
    # Every parameter added is directly written to an `IO`,
    # where keys and values are properly escaped.
    class Builder
      @io : IO
      @first : Bool

      def initialize(@io = IO::Memory.new)
        @first = true
      end

      # Adds a key-value pair to the params being built.
      def add(key, value)
        @io << '&' unless @first
        @first = false
        URI.escape key, @io
        @io << '='
        Params.encode_www_form_component value, @io if value
        self
      end

      def to_s(io)
        io << @io.to_s
      end
    end
  end
end
