require "./item"

class Crystal::Doc::Constant
  include Item

  getter type : Type
  getter const : Const

  def initialize(@generator : Generator, @type : Type, @const : Const)
  end

  def doc
    if inherit_docs?(@const.doc.try &.split)
      @type.constants.find { |cnst| cnst === @const }.try &.doc
    else  
      @const.doc
    end
  end
  
  def inherit_docs?(str : String)
    str.starts_with?(":inherit:") || str.starts_with?("inherit")
  end

  def name
    @const.name
  end

  def id
    name
  end

  def value
    @const.value
  end

  def formatted_value
    Highlighter.highlight value.to_s
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field "id", id
      builder.field "name", name
      builder.field "value", value.try(&.to_s)
      builder.field "doc", doc
      builder.field "summary", formatted_summary
    end
  end
end
