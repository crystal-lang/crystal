require "uri"
require "yaml"

class URI
  # Deserializes a URI from YAML, represented as a string.
  #
  # ```
  # require "uri/yaml"
  #
  # uri = URI.from_yaml(%("http://crystal-lang.org")) # => #<URI:0x1068a7e40 @scheme="http", @host="crystal-lang.org", ... >
  # uri.scheme                                        # => "http"
  # uri.host                                          # => "crystal-lang.org"
  # ```
  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    parse String.new(ctx, node)
  end

  # Serializes this URI to YAML, represented as a string.
  #
  # ```
  # require "uri/yaml"
  #
  # URI.parse("http://example.com").to_yaml # => "--- http://example.com\n"
  # ```
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar to_s
  end
end
