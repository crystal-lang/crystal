module Crystal::Doc::Primitive
  def self.doc(a_def, primitive)
    case primitive.name
    when :object_id
%(
Returns a UInt64 that uniquely identifies this object.

The returned value is the memory address of this object.

```
ref = Reference.new
pointer = Pointer(Reference).new(ref.object_id)
ref2 = pointer as Reference
ref2.object_id == ref.object_id #=> true
```
)
    when :binary
      case a_def.name
      when "=="
        "Returns true if this object is equal to other."
      when "!="
        "Returns true if this object is not equal to other."
      when "<"
        "Returns true if this object is less than other."
      when "<="
        "Returns true if this object is less than or equal to other."
      when ">"
        "Returns true if this object is greater than other."
      when ">="
        "Returns true if this object is greater than or equal to other."
      when "*"
        "Returns the result of multipling this object by other."
      else
        ""
        # raise "Bug: missing binary doc: #{a_def.name}"
      end
    else
      ""
      # raise "Bug: missing doc: #{primitive.name}"
    end
  end
end
