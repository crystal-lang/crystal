class Class
  def inspect(io)
    to_s(io)
  end

  macro def to_s(io) : Nil
    # If we are Foo, the name is "Foo:Class",
    # so we remove the ":Class" part
    io << {{@class_name[0 .. -7]}}
    nil
  end
end
