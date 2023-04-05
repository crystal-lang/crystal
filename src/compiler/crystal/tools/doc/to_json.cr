class Crystal::Arg
  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "doc", doc unless doc.nil?
      builder.field "default_value", default_value.to_s unless default_value.nil?
      builder.field "external_name", external_name.to_s
      builder.field "restriction", restriction.to_s
    end
  end
end

class Crystal::Def
  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "args", args unless args.empty?
      builder.field "double_splat", double_splat unless double_splat.nil?
      builder.field "splat_index", splat_index unless splat_index.nil?
      builder.field "yields", block_arity unless block_arity.nil?
      builder.field "block_arity", block_arity unless block_arity.nil?
      builder.field "block_arg", block_arg unless block_arg.nil?
      builder.field "return_type", return_type.to_s unless return_type.nil?
      builder.field "visibility", visibility.to_s
      builder.field "body", body.to_s
    end
  end
end

class Crystal::Macro
  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "args", args unless args.empty?
      builder.field "double_splat", double_splat unless double_splat.nil?
      builder.field "splat_index", splat_index unless splat_index.nil?
      builder.field "block_arg", block_arg unless block_arg.nil?
      builder.field "visibility", visibility.to_s
      builder.field "body", body.to_s
    end
  end
end
