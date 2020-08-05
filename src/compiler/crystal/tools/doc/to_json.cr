class Crystal::Arg
  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "doc", doc
      builder.field "default_value", default_value.to_s
      builder.field "external_name", external_name.to_s
      builder.field "restriction", restriction.to_s
    end
  end
end

class Crystal::Def
  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "args", args
      builder.field "double_splat", double_splat
      builder.field "splat_index", splat_index
      builder.field "yields", yields
      builder.field "block_arg", block_arg
      builder.field "return_type", return_type.to_s
      builder.field "visibility", visibility.to_s
      builder.field "body", body.to_s
    end
  end
end

class Crystal::Macro
  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "args", args
      builder.field "double_splat", double_splat
      builder.field "splat_index", splat_index
      builder.field "block_arg", block_arg
      builder.field "visibility", visibility.to_s
      builder.field "body", body.to_s
    end
  end
end
