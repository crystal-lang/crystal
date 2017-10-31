require "html"
require "uri"
require "./item"

class Crystal::Doc::Method
  include Item

  getter type : Type
  getter def : Def

  def initialize(@generator : Generator, @type : Type, @def : Def, @class_method : Bool)
  end

  def name
    @def.name
  end

  def args
    @def.args
  end

  def doc
    @def.doc
  end

  def source_link
    @generator.source_link(@def)
  end

  def prefix
    case
    when @type.program?
      ""
    when @class_method
      "."
    else
      "#"
    end
  end

  def constructor?
    return false unless @class_method
    return true if name == "new"

    return_type = self.return_type
    if return_type.is_a?(Union)
      if return_type.types.size == 2
        if @type.nil_type?(return_type.types[0])
          return_type = return_type.types[1]
        elsif @type.nil_type?(return_type.types[1])
          return_type = return_type.types[0]
        end
      end
    end
    {type.name, "self"}.includes?(return_type.to_s)
  end

  def abstract?
    @def.abstract?
  end

  def return_type
    return_type = @def.return_type

    # If the def's body is a single instance variable, we include
    # a return type since instance vars must have a fixed/guessed type,
    # so docs will be better and easier to navigate.
    if !return_type && (body = @def.body).is_a?(InstanceVar)
      owner = type.type
      if owner.is_a?(NonGenericClassType)
        ivar = owner.lookup_instance_var?(body.name)
        return_type = ivar.try &.type?
      end
    end
    return_type
  end

  def kind
    case
    when @type.program?
      "def "
    when @class_method
      "def self."
    else
      "def "
    end
  end

  def id
    String.build do |io|
      io << to_s.gsub(/<.+?>/, "").gsub(' ', "")
      if @class_method
        io << "-class-method"
      else
        io << "-instance-method"
      end
    end
  end

  def html_id
    HTML.escape(id)
  end

  def anchor
    "#" + URI.escape(id)
  end

  def to_s(io)
    io << name
    args_to_s io
  end

  def args_to_s
    String.build { |io| args_to_s io }
  end

  def args_to_s(io)
    args_to_html(io, links: false)
  end

  def args_to_html
    String.build { |io| args_to_html io }
  end

  def args_to_html(io, links = true)
    return_type = self.return_type

    return unless has_args? || return_type

    if has_args?
      io << '('
      printed = false
      @def.args.each_with_index do |arg, i|
        io << ", " if printed
        io << '*' if @def.splat_index == i
        arg_to_html arg, io, links: links
        printed = true
      end
      if double_splat = @def.double_splat
        io << ", " if printed
        io << "**"
        io << double_splat
        printed = true
      end
      if block_arg = @def.block_arg
        io << ", " if printed
        io << '&'
        arg_to_html block_arg, io, links: links
      elsif @def.yields
        io << ", " if printed
        io << "&block"
      end
      io << ')'
    end

    case return_type
    when ASTNode
      io << " : "
      node_to_html return_type, io, links: links
    when Crystal::Type
      io << " : "
      @type.type_to_html return_type, io, links: links
    end

    if free_vars = @def.free_vars
      io << " forall "
      free_vars.join(", ", io)
    end

    io
  end

  def arg_to_html(arg : Arg, io, links = true)
    if arg.external_name != arg.name
      io << (arg.external_name.empty? ? "_" : arg.external_name)
      io << " "
    end

    io << arg.name

    if restriction = arg.restriction
      io << " : "
      node_to_html restriction, io, links: links
    elsif type = arg.type?
      io << " : "
      @type.type_to_html type, io, links: links
    end
    if default_value = arg.default_value
      io << " = "
      io << Highlighter.highlight(default_value.to_s)
    end
  end

  def node_to_html(node, io, links = true)
    @type.node_to_html node, io, links: links
  end

  def must_be_included?
    @generator.must_include? @def
  end

  def has_args?
    !@def.args.empty? || @def.block_arg || @def.yields
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "id", id
      builder.field "html_id", html_id
      builder.field "name", name
      builder.field "doc", doc
      builder.field "summary", formatted_summary
      builder.field "abstract", abstract?
      builder.field "args", args
      builder.field "args_string", args_to_s
      builder.field "source_link", source_link
      builder.field "source_link", source_link
      builder.field "def", self.def
    end
  end
end
