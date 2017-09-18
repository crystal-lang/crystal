require "yaml"
require "big"

def BigInt.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Scalar)
    node.raise "Expected scalar, not #{node.class}"
  end

  BigInt.new(node.value)
end

def BigFloat.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Scalar)
    node.raise "Expected scalar, not #{node.class}"
  end

  BigFloat.new(node.value)
end
