require "yaml"
require "uuid"

struct UUID
  # Creates `UUID` from YAML using `YAML::ParseContext`.
  #
  # NOTE: `require "uuid/yaml"` is required to opt-in to this feature.
  #
  # ```
  # require "yaml"
  # require "uuid"
  # require "uuid/yaml"
  #
  # class Example
  #   include YAML::Serializable
  #
  #   property id : UUID
  # end
  #
  # example = Example.from_yaml("id: 50a11da6-377b-4bdf-b9f0-076f9db61c93")
  # example.id # => UUID(50a11da6-377b-4bdf-b9f0-076f9db61c93)
  # ```
  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
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

  # Returns `UUID` as YAML value.
  #
  # NOTE: `require "uuid/yaml"` is required to opt-in to this feature.
  #
  # ```
  # uuid = UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
  # uuid.to_yaml # => "--- 50a11da6-377b-4bdf-b9f0-076f9db61c93\n"
  # ```
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar self.to_s
  end
end
