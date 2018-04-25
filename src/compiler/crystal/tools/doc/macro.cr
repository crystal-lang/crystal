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

  def to_s(io)
    io << name
    args_to_s io
  end

  def args_to_s
    String.build { |io| args_to_s io }
  end

  def args_to_s(io)
    return if @macro.args.empty?

    printed = false
    io << '('

    @macro.args.each_with_index do |arg, i|
      io << ", " if printed
      io << '*' if @macro.splat_index == i
      io << arg
      printed = true
    end

    if double_splat = @macro.double_splat
      io << ", " if printed
      io << "**"
      io << double_splat
    end

    io << ')'
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
