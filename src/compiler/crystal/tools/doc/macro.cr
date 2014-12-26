require "./item"

class Crystal::Doc::Macro
  include Item

  getter :macro

  def initialize(@generator, @macro)
  end

  def name
    @macro.name
  end

  def doc
    @macro.doc
  end

  def anchor
    CGI.escape(to_s)
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

    io << '('
    @macro.args.each_with_index do |arg, i|
      io << ", " if i > 0
      io << arg
    end
    io << ')'
  end
end
