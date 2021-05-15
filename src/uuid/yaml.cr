require "json"
require "uuid"

def UUID.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  ctx.read_alias(node, String) do |obj|
    return UUID.new(obj)
  end

  if node.is_a?(YAML::Nodes::Scalar)
    value = node.value
    ctx.record_anchor(node, value)
    UUID.new(value)
  else
    node.raise "Expected String, not #{node.kind}"
  end
end

def UUID.to_yaml(yaml : YAML::Nodes::Builder)
  yaml.scalar self.to_s
end
