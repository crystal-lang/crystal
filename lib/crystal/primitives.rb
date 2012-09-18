module Crystal
  class Primitive < Def
  end

  def self.primitives
    @primitives ||= begin
      primitives = []

      Def.new(:+, [Var.new('other')])

      Parser.parse('def +(other); end').last
      [Type::Int, :+, [Type::Int], Type::Int, ->(f, b) { b.ret(b.add(f.params[0], f.params[1])) }]
      primitives
    end
  end
end