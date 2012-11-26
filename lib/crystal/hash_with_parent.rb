class HashWithParent < Hash
  def initialize(obj)
    @obj = obj
  end

  def [](key)
    value = super
    unless value
      @obj.parents.each do |parent|
        value = parent.defs[key] and break
      end
    end
    value
  end
end
