struct Function
  def ===(other)
    call(other)
  end

  macro def to_s(io) : Nil
    io << "#<{{@class_name.id}}:0x"
    pointer.address.to_s(16, io)
    if closure?
      io << ":closure"
    end
    io << ">"
    nil
  end
end
