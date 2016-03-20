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
    when :cast
      case a_def.name
      when "ord"
        %(
Returns this Char's Unicode codepoint.

```
'a'.ord  #=> 97
'あ'.ord #=> 12354
```
)
      else
        ""
      end
    when :binary
      case a_def.name
      when "=="
        "Returns true if this #{a_def.owner} is equal to `other`."
      when "!="
        "Returns true if this #{a_def.owner} is not equal to `other`."
      when "<"
        if a_def.owner.is_a?(CharType)
          "Returns true if this #{a_def.owner}'s codepoint is less than `other`'s."
        else
          "Returns true if this #{a_def.owner} is less than `other`."
        end
      when "<="
        if a_def.owner.is_a?(CharType)
          "Returns true if this #{a_def.owner}'s codepoint is less than or equal to `other`'s."
        else
          "Returns true if this #{a_def.owner} is less than or equal to `other`."
        end
      when ">"
        if a_def.owner.is_a?(CharType)
          "Returns true if this #{a_def.owner}'s codepoint is greater than `other`'s."
        else
          "Returns true if this #{a_def.owner} is greater than `other`."
        end
      when ">="
        if a_def.owner.is_a?(CharType)
          "Returns true if this #{a_def.owner}'s codepoint is greater than or equal to `other`'s."
        else
          "Returns true if this #{a_def.owner} is greater than or equal to `other`."
        end
      when "*"
        "Returns the result of multipling this #{a_def.owner} by `other`."
      else
        ""
        # raise "Bug: missing binary doc: #{a_def.name}"
      end
    when :pointer_malloc, :pointer_realloc, :pointer_add
      ":nodoc:" # documented in the Int overload
    when :pointer_address
      %(
Returns the address of this pointer.

```
ptr = Pointer(Int32).new(1234)
ptr.address #=> 1234
```
)
    when :pointer_get
      %(
Gets the value pointed by this pointer.

```
ptr = Pointer(Int32).malloc(4)
ptr.value = 42
ptr.value #=> 42
```
)
    when :pointer_set
      %(
Sets the value pointed by this pointer.

```
ptr = Pointer(Int32).malloc(4)
ptr.value = 42
ptr.value #=> 42
```
)
    when :pointer_diff
      %(
Returns how many T elements are there between this pointer and *other*.
That is, this is `(self.address - other.address) / sizeof(T)`.

```
ptr1 = Pointer(Int32).malloc(4)
ptr2 = ptr1 + 2
ptr2 - ptr1 #=> 2
```
)
    else
      ""
      # raise "Bug: missing doc: #{primitive.name}"
    end
  end
end
