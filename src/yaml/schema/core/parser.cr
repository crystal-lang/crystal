# :nodoc:
class YAML::Schema::Core::Parser < YAML::Parser
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
    [] of YAML::Any
  end

  def new_document : YAML::Any
    Any.new([] of Any)
  end

  def cast_document(document) : YAML::Any
    document.as_a.first? || Any.new(nil)
  end

  def new_sequence : YAML::Any
    Any.new([] of Any)
  end

  def new_mapping : YAML::Any
    Any.new({} of Any => Any)
  end

  def new_scalar : YAML::Any
    Any.new(Core.parse_scalar(@pull_parser))
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

  def add_to_mapping(mapping, key, value)
    mapping.as_h[key] = value
  end

  protected def parse_mapping
    mapping = anchor new_mapping
    raw_mapping = mapping.as_h

    parse_mapping(mapping) do
      tag = @pull_parser.tag
      key = parse_node
      raw_key = key.raw

      value = parse_node

      if raw_key == "<<" && tag != "tag:yaml.org,2002:str"
        case raw = value.raw
        when Hash
          mapping.as_h.merge!(raw)
        when Array
          if raw.all? &.as_h?
            raw.each do |elem|
              raw_mapping.merge!(elem.as_h)
            end
          else
            raw_mapping[key] = value
          end
        else
          raw_mapping[key] = value
        end
      else
        raw_mapping[key] = value
      end
    end

    mapping
  end

  def process_tag(tag, &)
    if value = process_collection_tag(@pull_parser, tag)
      yield value
    end

    Core.process_scalar_tag(@pull_parser, tag) do |value|
      @pull_parser.read_next
      yield Any.new(value)
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

    pairs = [] of Any

    parse_sequence(pairs) do
      @pull_parser.expect_kind EventKind::MAPPING_START
      @pull_parser.read_next

      pairs << Any.new({parse_node => parse_node} of Any => Any)

      @pull_parser.expect_kind EventKind::MAPPING_END
      @pull_parser.read_next
    end

    Any.new(pairs)
  end

  private def parse_set
    @pull_parser.expect_kind EventKind::MAPPING_START

    set = Set(Any).new

    parse_mapping(set) do
      set << parse_node

      parse_node # discard value
    end

    Any.new(set)
  end
end
