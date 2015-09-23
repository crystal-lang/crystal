require "uri"

module HTTP
  class Params
    # Parses an HTTP query string into a `HTTP::Params`
    #
    #     HTTP::Params.parse("foo=bar&foo=baz&qux=zoo") #=> {"foo" => ["bar", "baz"], "qux" => ["zoo"]}
    def self.parse(query : String)
      parsed = {} of String => Array(String)
      parse(query) do |key, value|
        ary = parsed[key] ||= [] of String
        ary.push value
      end
      Params.new(parsed)
    end

    # Parses an HTTP query and yields each key-value pair
    #
    #     HTTP::Params.parse(query) do |key, value|
    #       # ...
    #     end
    def self.parse(query : String)
      key = nil
      buffer = StringIO.new

      i = 0
      bytesize = query.bytesize
      while i < bytesize
        byte = query.unsafe_byte_at(i)
        char = byte.chr

        case char
        when '='
          key = buffer.to_s
          buffer.clear
          i += 1
        when '&', ';'
          value = buffer.to_s
          buffer.clear

          if key
            yield key.not_nil!, value
          else
            yield value, ""
          end

          key = nil
          i += 1
        else
          i = URI.unescape_one query, bytesize, i, byte, char, buffer
        end
      end

      if key
        yield key.not_nil!, buffer.to_s
      else
        yield buffer.to_s, ""
      end
    end

    # Builds an url-encoded HTTP form/query.
    #
    # The yielded object has an `add` method that accepts two arguments,
    # a key (String) and a value (String or Nil). Keys and values are escaped
    # using `URI#escape`.
    #
    # ```
    # params = HTTP::Params.build do |form|
    #   form.add "color", "black"
    #   form.add "name", "crystal"
    #   form.add "year", "2012 - today"
    # end
    # params #=> "color=black&name=crystal&year=2012%20-%20today"
    # ```
    def self.build
      form_builder = Builder.new
      yield form_builder
      form_builder.to_s
    end

    protected getter raw_params
    def initialize(@raw_params)
    end

    def ==(other : self)
      self.raw_params == other.raw_params
    end

    def ==(other)
      false
    end

    # Returns first value for specified param name.
    def [](name)
      raw_params[name].first
    end

    # Returns true if param with provided name exists.
    #
    # ```
    # params.has_key?("email")       # => true
    # params.has_key?("garbage")     # => false
    # ```
    delegate has_key?, raw_params

    # Sets first value for specified param name.
    def []=(name, value)
      raw_params[name] ||= [""]
      raw_params[name][0] = value
    end

    # Returns all values for specified param name.
    def fetch_all(name)
      raw_params.fetch(name) { [] of String }
    end

    # Returns first value for specified param name.
    def fetch(name)
      raw_params.fetch(name).first
    end

    # Returns first value for specified param name. Fallbacks to provided
    # default value when there is no such param.
    def fetch(name, default)
      raw_params.fetch(name, [default]).first
    end

    # Returns first value for specified param name. Fallbacks to return value
    # of provided block.
    def fetch(name, &block : -> String)
      raw_params.fetch(name) { [block.call] }.first
    end

    # Appends new value for specified param name. Creates param when there was
    # no such param.
    def add(name, value)
      raw_params[name] ||= [] of String
      raw_params[name] = [] of String if raw_params[name] == [""]
      raw_params[name] << value
    end

    # Sets all values for specified param name at once.
    def set_all(name, values)
      raw_params[name] = values
    end

    # Allows to iterate over all name-value pairs.
    def each
      raw_params.each do |name, values|
        values.each do |value|
          yield(name, value)
        end
      end
    end

    # Deletes first value for provided param name. If there are no values left,
    # deletes param itself. Returns deleted value.
    def delete(name)
      value = raw_params[name].shift
      raw_params.delete(name) if raw_params[name].size == 0
      value
    end

    # Deletes all values for provided param name. Returns array of deleted
    # values.
    def delete_all(name)
      raw_params.delete(name)
    end

    # Serializes to string representation as http url encoded form
    def to_s(io)
      io << HTTP::Params.build do |builder|
        each do |name, value|
          builder.add(name, value)
        end
      end
    end

    # :nodoc:
    struct Builder
      def initialize
        @string = StringIO.new
      end

      def add(key, value)
        @string << '&' unless @string.empty?
        URI.escape key, @string
        @string << '='
        URI.escape value, @string if value
        self
      end

      def to_s(io)
        io << @string.to_s
      end
    end
  end
end
