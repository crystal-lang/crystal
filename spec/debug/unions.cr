struct ProbePoint
  @x : Int32

  def initialize(@x)
  end
end

class ProbeRef
  @name : String

  def initialize(@name)
  end
end

class ProbeAlt
  @value : Int32

  def initialize(@value)
  end
end

int_value = 123.as(Int32 | String | Nil)
string_value = "hello".as(Int32 | String | Nil)
nil_value = nil.as(Int32 | String | Nil)

bool_value = true.as(Bool | Int32)
false_value = false.as(Bool | Int32)
int_from_bool_union = 42.as(Bool | Int32)

point_value = ProbePoint.new(7).as(ProbePoint | ProbeRef | Nil)
ref_value = ProbeRef.new("box").as(ProbePoint | ProbeRef | Nil)

nilable_string = "abc".as(String | Nil)
nilable_ref = ProbeRef.new("maybe").as(ProbeRef | Nil)
reference_union = ProbeAlt.new(9).as(ProbeRef | ProbeAlt | Nil)
reference_union_nil = nil.as(ProbeRef | ProbeAlt | Nil)

# print: int_value
# lldb-check: ((Int32 | String | Nil)) {{(\$[0-9]+ = )?}}Int32 = 123
# print: string_value
# lldb-check: ((Int32 | String | Nil)) {{(\$[0-9]+ = )?}}String = "hello"
# print: nil_value
# lldb-check: ((Int32 | String | Nil)) {{(\$[0-9]+ = )?}}Nil
# print: bool_value
# lldb-check: ((Bool | Int32)) {{(\$[0-9]+ = )?}}Bool = true
# print: false_value
# lldb-check: ((Bool | Int32)) {{(\$[0-9]+ = )?}}Bool = false
# print: int_from_bool_union
# lldb-check: ((Bool | Int32)) {{(\$[0-9]+ = )?}}Int32 = 42
# print: point_value
# lldb-check: ((ProbePoint | ProbeRef | Nil)) {{(\$[0-9]+ = )?}}ProbePoint = (x = 7)
# print: ref_value
# lldb-check: ((ProbePoint | ProbeRef | Nil)) {{(\$[0-9]+ = )?}}ProbeRef = (name = "box")
# print: nilable_string
# lldb-check: ((String | Nil) *) {{(0x[0-9a-f]+ )?}}"abc"
# print: nilable_ref
# lldb-check: ((ProbeRef | Nil) *) {{(0x[0-9a-f]+ )?}}ProbeRef = (name = "maybe")
# print: reference_union
# lldb-check: ((ProbeAlt | ProbeRef | Nil)) {{(\$[0-9]+ = )?}}ProbeAlt = (value = 9)
# print: reference_union_nil
# lldb-check: ((ProbeAlt | ProbeRef | Nil)) {{(\$[0-9]+ = )?}}Nil
debugger
