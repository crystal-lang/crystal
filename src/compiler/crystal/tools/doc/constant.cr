require "./item"

class Crystal::Doc::Constant
  include Item

  getter type
  getter const

  def initialize(@generator, @type : Type, @const)
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
end
