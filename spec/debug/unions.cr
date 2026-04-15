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

# print: a
# lldb-check: ((Int32 | String)) 42
# print: b
# lldb-check: ((Int32 | String)) "forty-two"
# print: c
# lldb-check: ((Int32 | Nil)) 7
# print: d
# lldb-check: ((Int32 | Nil)) Nil
debugger
