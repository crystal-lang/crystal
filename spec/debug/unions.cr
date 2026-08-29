def int_or_string(flag)
  if flag
    42.as(Int32 | String)
  else
    "forty-two".as(Int32 | String)
  end
end

def int_or_nil(flag)
  if flag
    7.as(Int32 | Nil)
  else
    nil.as(Int32 | Nil)
  end
end

a = int_or_string(true)
b = int_or_string(false)
c = int_or_nil(true)
d = int_or_nil(false)
e = [
  42.as(Int32 | String | Nil),
  "forty-two".as(Int32 | String | Nil),
  nil.as(Int32 | String | Nil),
]

# print: a
# lldb-check: ((Int32 | String)) 42
# print: b
# lldb-check: ((Int32 | String)) "forty-two"
# print: c
# lldb-check: ((Int32 | Nil)) 7
# print: d
# lldb-check: ((Int32 | Nil)) Nil
# print: *e
# lldb-check: (Array(Int32 | String | Nil)) {{(\$[0-9]+ = )?}}[42, "forty-two", Nil] {
# lldb-check:   [0] = 42
# lldb-check:   [1] = "forty-two"
# lldb-check:   [2] = Nil
# lldb-check: }
debugger
