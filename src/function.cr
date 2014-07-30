struct Function
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
