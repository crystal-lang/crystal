require "html"
require "uri"
require "./item"

class Crystal::Doc::Macro
  include Item

  getter type : Type
  getter macro : Crystal::Macro

  def initialize(@generator : Generator, @type : Type, @macro : Crystal::Macro)
  end

  def name
    @macro.name
  end

  def args
    @macro.args
  end

  def doc
    @macro.doc
  end

  def source_link
    @generator.source_link(@macro)
  end

  def id
    String.build do |io|
      io << to_s.gsub(/<.+?>/, "").gsub(' ', "")
      io << "-macro"
    end
  end

  def html_id
    HTML.escape(id)
  end

  def anchor
    "#" + URI.escape(id)
  end

  def prefix
    ""
  end

  def abstract?
    false
  end

  def kind
    "macro "
  end

  def to_s(io : IO) : Nil
    io << name
    args_to_s io
  end

  def args_to_s
    String.build { |io| args_to_s io }
  end

  def args_to_s(io : IO) : Nil
    return unless has_args?

    printed = false
    io << '('

    @macro.args.each_with_index do |arg, i|
      io << ", " if printed
      io << '*' if @macro.splat_index == i
      arg_to_s arg, io
      printed = true
    end

    if double_splat = @macro.double_splat
      io << ", " if printed
      io << "**"
      arg_to_s double_splat, io
      printed = true
    end

    if block_arg = @macro.block_arg
      io << ", " if printed
      io << '&'
      arg_to_s block_arg, io
    end

    io << ')'
  end

  def arg_to_s(arg : Arg, io : IO) : Nil
    if arg.external_name != arg.name
      name = arg.external_name.empty? ? "_" : arg.external_name
      if Symbol.needs_quotes? name
        HTML.escape name.inspect, io
      else
        io << name
      end
      io << ' '
    end

    io << arg.name

    # Macro arg cannot not have a restriction.

    if default_value = arg.default_value
      io << " = "
      io << Highlighter.highlight(default_value.to_s)
    end
  end

  def has_args?
    !@macro.args.empty? || @macro.double_splat || @macro.block_arg
  end

  def args_to_html
    args_to_s
  end

  def must_be_included?
    @generator.must_include? @macro
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
      builder.field "def", self.macro
    end
  end
end
