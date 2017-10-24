# Provides a way to parse a YAML document according to the
# fail-safe schema, as specified in http://www.yaml.org/spec/1.2/spec.html#id2802346,
# where all scalar values are considered strings.
module YAML::Schema::FailSafe
  # Deserializes a YAML document.
  def self.parse(data : String | IO) : Any
    Parser.new data, &.parse
  end

  # Deserializes multiple YAML documents.
  def self.parse_all(data : String | IO) : Any
    Parser.new data, &.parse_all
  end

  # :nodoc:
  class Parser < YAML::Parser
    @anchors = {} of String => Any

    def put_anchor(anchor, value)
      @anchors[anchor] = value
    end

    def get_anchor(anchor)
      @anchors.fetch(anchor) do
        @pull_parser.raise("Unknown anchor '#{anchor}'")
      end
    end

    def new_documents
      [] of Any
    end

    def new_document
      Any.new([] of Any)
    end

    def cast_document(doc)
      doc.first? || Any.new(nil)
    end

    def new_sequence
      Any.new([] of Any)
    end

    def new_mapping
      Any.new({} of Any => Any)
    end

    def new_scalar
      Any.new(@pull_parser.value)
    end

    def add_to_documents(documents, document)
      documents << document
    end

    def add_to_document(document, node)
      document.as_a << node
    end

    def add_to_sequence(sequence, node)
      sequence.as_a << node
    end

    def add_to_mapping(mapping, key, value)
      mapping.as_h[key] = value
    end
  end
end
