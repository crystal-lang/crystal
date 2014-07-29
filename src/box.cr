class Box(T)
  getter object

  def initialize(@object : T)
  end

  def self.box(object)
    new(object) as Void*
  end

  def self.unbox(pointer : Void*)
    (pointer as self).object
  end
end
