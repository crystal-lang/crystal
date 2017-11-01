require "./item"

class Crystal::Doc::Constant
  include Item

  getter type : Type
  getter const : Const

  def initialize(@generator : Generator, @type : Type, @const : Const)
  end

  def doc
    @const.doc
  end

  def name
    @const.name
  end

  def value
    @const.value
  end

  def formatted_value
    Highlighter.highlight value.to_s
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "name", name
      builder.field "value", value.try(&.to_s)
      builder.field "doc", doc
      builder.field "summary", formatted_summary
    end
  end
end
