# Parsing context that holds anchors and what they refer to.
#
# When implementing `new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)`
# to deserialize an object from a node, `Reference` types must invoke
# both `read_alias` and `record_anchor` in order to support parsing
# recursive data structures.
#
# - `read_alias` must be invoked before an instance is created
# - `record_anchor` must be invoked after an instance is created and
#   before its members are deserialized.
class YAML::ParseContext
  def initialize
    # Recorded anchors: anchor => {object_id, crystal_type_id}
    @anchors = {} of String => {UInt64, Int32}
  end

  # Associates an object with an anchor.
  def record_anchor(node, object : T) : Nil forall T
    return unless object.is_a?(Reference)

    record_anchor(node.anchor, object.object_id, object.crystal_type_id)
  end

  private def record_anchor(anchor, object_id, crystal_type_id)
    return unless anchor

    @anchors[anchor] = {object_id, crystal_type_id}
  end

  # Tries to read an alias from `node` of type `T`. Invokes
  # the block if successful, and invokers must return this object
  # instead of deserializing their members.
  def read_alias(node, type : T.class) forall T
    if ptr = read_alias_impl(node, T.crystal_instance_type_id, raise_on_alias: true)
      yield ptr.unsafe_as(T)
    end
  end

  # Similar to `read_alias` but doesn't raise if an alias exists
  # but an instance of type T isn't associated with the current anchor.
  def read_alias?(node, type : T.class) forall T
    if ptr = read_alias_impl(node, T.crystal_instance_type_id, raise_on_alias: false)
      yield ptr.unsafe_as(T)
    end
  end

  private def read_alias_impl(node, expected_crystal_type_id, raise_on_alias)
    if node.is_a?(YAML::Nodes::Alias)
      value = @anchors[node.anchor]?

      if value
        object_id, crystal_type_id = value
        if crystal_type_id == expected_crystal_type_id
          return Pointer(Void).new(object_id)
        end
      end

      raise("Error deserailizing alias") if raise_on_alias
    end

    nil
  end
end
