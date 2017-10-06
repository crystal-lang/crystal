# :nodoc:
class YAML::Schema::Core::Parser < YAML::Parser
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
    [] of YAML::Any
  end

  def new_document
    [] of Type
  end

  def cast_document(document)
    document.first?
  end

  def new_sequence
    [] of Type
  end

  def new_mapping
    {} of Type => Type
  end

  def new_scalar
    Core.parse_scalar(@pull_parser)
  end

  def cast_value(value)
    YAML::Any.new(value)
  end

  protected def parse_mapping
    mapping = anchor new_mapping

    parse_mapping(mapping) do
      tag = @pull_parser.tag
      key = parse_node

      location = @pull_parser.location
      value = parse_node

      if key == "<<" && tag != "tag:yaml.org,2002:str"
        case value
        when Hash
          mapping.merge!(value)
        when Array
          if value.all? &.is_a?(Hash)
            value.each do |elem|
              mapping.merge!(elem.as(Hash))
            end
          else
            mapping[key] = value
          end
        else
          mapping[key] = value
        end
      else
        mapping[key] = value
      end
    end

    mapping
  end

  def process_tag(tag)
    if value = process_collection_tag(@pull_parser, tag)
      yield value
    end

    Core.process_scalar_tag(@pull_parser, tag) do |value|
      @pull_parser.read_next
      yield value
    end
  end

  private def process_collection_tag(pull_parser, tag)
    case tag
    when "tag:yaml.org,2002:map",
         "tag:yaml.org,2002:omap"
      parse_mapping
    when "tag:yaml.org,2002:pairs"
      parse_pairs
    when "tag:yaml.org,2002:set"
      parse_set
    when "tag:yaml.org,2002:seq"
      parse_sequence
    else
      nil
    end
  end

  private def parse_pairs
    @pull_parser.expect_kind EventKind::SEQUENCE_START

    pairs = [] of Type

    parse_sequence(pairs) do
      @pull_parser.expect_kind EventKind::MAPPING_START
      @pull_parser.read_next

      pairs << {parse_node => parse_node} of Type => Type

      @pull_parser.expect_kind EventKind::MAPPING_END
      @pull_parser.read_next
    end

    pairs
  end

  private def parse_set
    @pull_parser.expect_kind EventKind::MAPPING_START

    set = Set(Type).new

    parse_mapping(set) do
      set << parse_node

      parse_node # discard value
    end

    set
  end
end
