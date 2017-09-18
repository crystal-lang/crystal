# Builds a tree of YAML nodes.
#
# This builder is similar to `YAML::Builder`, but instead of
# directly emitting the output to an IO it builds a YAML document
# tree in memory.
#
# All "emitting" methods support specifying a "reference" object
# that will be associated to the emitted object,
# so that when that reference object is emitted again an anchor
# and an alias will be created. This generates both more compact
# documents and allows handling recursive data structures.
class YAML::Nodes::Builder
  @current : Node

  # The document this builder builds.
  getter document : Document

  def initialize
    @document = Document.new
    @current = @document
    @object_id_to_node = {} of UInt64 => Node
    @anchor_count = 0
  end

  def scalar(value, anchor : String? = nil, tag : String? = nil,
             style : YAML::ScalarStyle = YAML::ScalarStyle::ANY,
             reference = nil) : Nil
    node = Scalar.new(value.to_s)
    node.anchor = anchor
    node.tag = tag
    node.style = style

    if register(reference, node)
      return
    end

    push_node(node)
  end

  def sequence(anchor : String? = nil, tag : String? = nil,
               style : YAML::SequenceStyle = YAML::SequenceStyle::ANY,
               reference = nil) : Nil
    node = Sequence.new
    node.anchor = anchor
    node.tag = tag
    node.style = style

    if register(reference, node)
      return
    end

    push_to_stack(node) do
      yield
    end
  end

  def mapping(anchor : String? = nil, tag : String? = nil,
              style : YAML::MappingStyle = YAML::MappingStyle::ANY,
              reference = nil) : Nil
    node = Mapping.new
    node.anchor = anchor
    node.tag = tag
    node.style = style

    if register(reference, node)
      return
    end

    push_to_stack(node) do
      yield
    end
  end

  private def push_node(node)
    case current = @current
    when Document
      current << node
    when Sequence
      current << node
    when Mapping
      current << node
    end
  end

  private def push_to_stack(node)
    push_node(node)

    old_current = @current
    @current = node

    yield

    @current = old_current
  end

  private def register(object, current_node)
    if object.is_a?(Reference)
      register_object_id(object.object_id, current_node)
    else
      false
    end
  end

  private def register_object_id(object_id, current_node)
    node = @object_id_to_node[object_id]?

    if node
      anchor = node.anchor ||= begin
        @anchor_count += 1
        @anchor_count.to_s
      end

      node = Alias.new(anchor)
      push_node(node)
      true
    else
      @object_id_to_node[object_id] = current_node
      false
    end
  end
end
