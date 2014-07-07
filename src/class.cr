class Class
  def inspect
    to_s
  end

  def to_s : String
    # If we are Foo, the name is "Foo:Class",
    # so we remove the ":Class" part
    {{@name[0 .. -7]}}
  end
end
