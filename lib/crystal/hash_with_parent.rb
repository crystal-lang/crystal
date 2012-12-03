class HashWithParent < Hash
  def initialize(obj)
    @obj = obj
  end

  def [](key)
    value = super
    unless value
      @obj.parents.each do |parent|
        value = parent.lookup_def(key) and break
      end
    end
    value
  end
end
