# Provides a way to parse a YAML document according to the
# fail-safe schema, as specified in http://www.yaml.org/spec/1.2/spec.html#id2802346,
# where all scalar values are considered strings.
module YAML::Schema::FailSafe
  # All possible types according to the failsafe schema
  alias Type = String | Hash(Type, Type) | Array(Type) | Nil

  # Deserializes a YAML document.
  def self.parse(data : String | IO) : Type
    Parser.new data, &.parse
  end

  # Deserializes multiple YAML documents.
  def self.parse_all(data : String | IO) : Type
    Parser.new data, &.parse_all
  end

  # :nodoc:
  class Parser < YAML::Parser
    @anchors = {} of String => Type

    def put_anchor(anchor, value)
      @anchors[anchor] = value
    end

    def get_anchor(anchor)
      @anchors.fetch(anchor) do
        @pull_parser.raise("Unknown anchor '#{anchor}'")
      end
    end

    def new_documents
      [] of Type
    end

    def new_document
      [] of Type
    end

    def cast_document(doc)
      doc.first?
    end

    def new_sequence
      [] of Type
    end

    def new_mapping
      {} of Type => Type
    end

    def new_scalar
      @pull_parser.value
    end
  end
end
