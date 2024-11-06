a = [0, 1, 4, 9, 16, 25]
# print: *a
# lldb-check: (Array(Int32)) $0 = ([0] = 0, [1] = 1, [2] = 4, [3] = 9, [4] = 16, [5] = 25)
# gdb-check: $1 = Array(Int32) = {0, 1, 4, 9, 16, 25}
debugger
a << 36
# print: *a
# lldb-check: (Array(Int32)) $1 = ([0] = 0, [1] = 1, [2] = 4, [3] = 9, [4] = 16, [5] = 25, [6] = 36)
# gdb-check: $2 = Array(Int32) = {0, 1, 4, 9, 16, 25, 36}
debugger
a.unshift 49
# print: *a
# lldb-check: (Array(Int32)) $2 = ([0] = 49, [1] = 0, [2] = 1, [3] = 4, [4] = 9, [5] = 16, [6] = 25, [7] = 36)
# gdb-check: $3 = Array(Int32) = {49, 0, 1, 4, 9, 16, 25, 36}
debugger
