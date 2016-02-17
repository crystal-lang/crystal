require "html"
require "uri"
require "./item"

class Crystal::Doc::Method
  include Item

  getter type
  getter :def

  def initialize(@generator, @type, @def, @class_method)
  end

  def name
    @def.name
  end

  def args
    @def.args
  end

  def doc
    body = @def.body
    if body.is_a?(Crystal::Primitive)
      Primitive.doc @def, body
    else
      @def.doc
    end
  end

  def source_link
    @generator.source_link(@def)
  end

  def prefix
    @class_method ? '.' : '#'
  end

  def abstract?
    @def.abstract
  end

  def kind
    @class_method ? "def self." : "def "
  end

  def id
    String.build do |io|
      io << to_s.gsub(' ', "")
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
    return unless has_args? || @def.return_type

    if has_args?
      io << '('
      @def.args.each_with_index do |arg, i|
        io << ", " if i > 0
        io << '*' if @def.splat_index == i
        arg_to_html arg, io, links: links
      end
      if block_arg = @def.block_arg
        io << ", " unless @def.args.empty?
        io << '&'
        arg_to_html block_arg, io, links: links
      elsif @def.yields
        io << ", " unless @def.args.empty?
        io << "&block"
      end
      io << ')'
    end

    if return_type = @def.return_type
      io << " : "
      node_to_html return_type, io, links: links
    end

    io
  end

  def arg_to_html(arg : Arg, io, links = true)
    io << arg.name
    if default_value = arg.default_value
      io << " = "
      io << Highlighter.highlight(default_value.to_s)
    end
    if restriction = arg.restriction
      io << " : "
      node_to_html restriction, io, links: links
    elsif type = arg.type?
      io << " : "
      @type.type_to_html type, io, links: links
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
end
