require "./item"

class Crystal::Doc::Method
  include Item

  getter :def

  def initialize(@generator, @type, @def, @class_method)
  end

  def name
    @def.name
  end

  def doc
    @def.doc
  end

  def source_link
    @generator.source_link(@def)
  end

  def prefix
    @class_method ? '.' : '#'
  end

  def anchor
    String.build do |io|
      CGI.escape(to_s, io)
      if @class_method
        io << "-class-method"
      else
        io << "-instance-method"
      end
    end
  end

  def to_s(io)
    io << name
    args_to_s io
  end

  def args_to_s
    String.build { |io| args_to_s io }
  end

  def args_to_s(io)
    return if @def.args.empty? && !@def.block_arg && !@def.yields

    io << '('
    @def.args.each_with_index do |arg, i|
      io << ", " if i > 0
      io << arg
    end
    if @def.block_arg
      io << ", " unless @def.args.empty?
      io << '&'
      io << @def.block_arg
    elsif @def.yields
      io << ", " unless @def.args.empty?
      io << "&block"
    end
    io << ')'
  end
end
