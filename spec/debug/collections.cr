h = {"a" => 1, "b" => 2, "c" => 3}
s = Set{1, 2, 3}
r1 = 1..3
r2 = 1...3
# print: *h
# lldb-check: (Hash(String, Int32)) {{(\$[0-9]+ = )?}}{
# lldb-check:   [0] = (hash = {{[0-9]+}}, key = "a", value = 1)
# lldb-check:   [1] = (hash = {{[0-9]+}}, key = "b", value = 2)
# lldb-check:   [2] = (hash = {{[0-9]+}}, key = "c", value = 3)
# lldb-check: }
# print: s
# lldb-check: (Set(Int32)) {{(\$[0-9]+ = )?}}Set{1, 2, 3}
# print: r1
# lldb-check: (Range(Int32, Int32)) {{(\$[0-9]+ = )?}}1..3
# print: r2
# lldb-check: (Range(Int32, Int32)) {{(\$[0-9]+ = )?}}1...3
debugger

h.delete("b")
s.delete(2)
# print: *h
# lldb-check: (Hash(String, Int32)) {{(\$[0-9]+ = )?}}{
# lldb-check:   [0] = (hash = {{[0-9]+}}, key = "a", value = 1)
# lldb-check:   [1] = (hash = {{[0-9]+}}, key = "c", value = 3)
# lldb-check: }
# print: s
# lldb-check: (Set(Int32)) {{(\$[0-9]+ = )?}}Set{1, 3}
debugger
