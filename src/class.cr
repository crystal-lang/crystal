class Class
  def inspect(io)
    to_s(io)
  end

  macro def to_s(io) : Nil
    class_name = {{@class_name}}
    if class_name.ends_with?(":Class")
      class_name = class_name[0 .. -7]
    end
    io << class_name
    nil
  end
end
