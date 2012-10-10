class HashWithParent < Hash
  def initialize(parent)
    @parent = parent
  end

  def [](key)
    value = super || @parent[key]
  end
end
