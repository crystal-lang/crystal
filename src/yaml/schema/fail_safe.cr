# Provides a way to parse a YAML document according to the
# fail-safe schema, as specified in http://www.yaml.org/spec/1.2/spec.html#id2802346,
# where all scalar values are considered strings.
module YAML::Schema::FailSafe
  # Deserializes a YAML document.
  def self.parse(data : String | IO, options : Options = Options.new) : Any
    Parser.new data, options, &.parse
  end

  # Same as `.parse(String | IO, Options)` but passing options as keyword
  # arguments.
  def self.parse(data : String | IO, **options) : YAML::Any
    Parser.new data, Options.new(**options), &.parse
  end

  # Deserializes multiple YAML documents.
  def self.parse_all(data : String | IO, options : Options = Options.new) : Array(Any)
    Parser.new data, options, &.parse_all
  end

  # Same as `.parse_all(String | IO, Options)` but passing options as keyword
  # arguments.
  def self.parse_all(data : String | IO, **options) : Array(YAML::Any)
    Parser.new data, Options.new(**options), &.parse_all
  end

  # :nodoc:
  class Parser < YAML::Parser
    @anchors = {} of String => Any

    def put_anchor(anchor, value)
      @anchors[anchor] = value
    end

    def get_anchor(anchor) : YAML::Any
      @anchors.fetch(anchor) do
        @pull_parser.raise("Unknown anchor '#{anchor}'")
      end
    end

    def new_documents : Array(YAML::Any)
      [] of Any
    end

    def new_document : YAML::Any
      Any.new([] of Any)
    end

    def cast_document(doc) : YAML::Any
      doc[0]? || Any.new(nil)
    end

    def new_sequence : YAML::Any
      Any.new([] of Any)
    end

    def new_mapping : YAML::Any
      Any.new({} of Any => Any)
    end

    def new_scalar : YAML::Any
      Any.new(@pull_parser.value)
    end

    def add_to_documents(documents, document) : Nil
      documents << document
    end

    def add_to_document(document, node) : Nil
      document.as_a << node
    end

    def add_to_sequence(sequence, node) : Nil
      sequence.as_a << node
    end

    def add_to_mapping(mapping, key, value) : Nil
      mapping.as_h[key] = value
    end
  end
end
