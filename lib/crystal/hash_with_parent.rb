class HashWithParent < Hash
  def initialize(obj)
    @obj = obj
  end

  alias_method :lookup_without_hierarchy, :[]

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
