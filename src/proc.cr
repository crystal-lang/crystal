struct Proc
  def self.new(pointer : Void*, closure_data : Void*)
    func = {pointer, closure_data}
    ptr = pointerof(func) as self*
    ptr.value
  end

  def pointer
    internal_representation[0]
  end

  def closure_data
    internal_representation[1]
  end

  def closure?
    !closure_data.nil?
  end

  private def internal_representation
    func = self
    ptr = pointerof(func) as {Void*, Void*}*
    ptr.value
  end

  def ===(other)
    call(other)
  end

  def to_s(io)
    io << "#<"
    io << {{@class_name}}
    io << ":0x"
    pointer.address.to_s(16, io)
    if closure?
      io << ":closure"
    end
    io << ">"
    nil
  end
end
