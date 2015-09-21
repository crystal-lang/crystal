require "uri"

module HTTP
  module Params
    # Parses an HTTP query string into a `Hash(String, Array(String))`
    #
    #     HTTP::Params.parse("foo=bar&foo=baz&qux=zoo") #=> {"foo" => ["bar", "baz"], "qux" => ["zoo"]}
    def self.parse(query : String)
      parsed = {} of String => Array(String)
      parse(query) do |key, value|
        ary = parsed[key] ||= [] of String
        ary.push value
      end
      parsed
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

      def to_s
        @string.to_s
      end
    end
  end
end
