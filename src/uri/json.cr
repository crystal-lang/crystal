require "uri"
require "json"

class URI
  # Deserializes a URI from JSON, represented as a string.
  #
  # ```
  # require "uri/json"
  #
  # uri = URI.from_json(%("http://crystal-lang.org")) # => #<URI:0x1068a7e40 @scheme="http", @host="crystal-lang.org", ... >
  # uri.scheme                                        # => "http"
  # uri.host                                          # => "crystal-lang.org"
  # ```
  def self.new(parser : JSON::PullParser)
    parse parser.read_string
  end

  # Serializes this URI to JSON, represented as a string.
  #
  # ```
  # require "uri/json"
  #
  # URI.parse("http://example.com").to_json # => %("http://example.com")
  # ```
  def to_json(builder : JSON::Builder)
    builder.string self
  end

  # Deserializes the given JSON *key* into a `URI`
  #
  # NOTE: `require "uri/json"` is required to opt-in to this feature.
  def self.from_json_object_key?(key : String) : URI?
    parse key
  rescue URI::Error
    nil
  end

  # :nodoc:
  def to_json_object_key : String
    to_s
  end
end
