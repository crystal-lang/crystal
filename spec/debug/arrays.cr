a = [0, 1, 4, 9, 16, 25]
# print: *a
# lldb-check: (Array(Int32)){{( \$[0-9]+ =)?  *}}[0, 1, 4, 9, 16, ... (6 total)] {
# lldb-check:   [0] = 0
# gdb-check: $1 = Array(Int32) = {0, 1, 4, 9, 16, 25}
debugger
a << 36
# print: *a
# lldb-check: (Array(Int32)){{( \$[0-9]+ =)?  *}}[0, 1, 4, 9, 16, ... (7 total)] {
# lldb-check:   [0] = 0
# lldb-check:   [1] = 1
# lldb-check:   [2] = 4
# lldb-check:   [3] = 9
# lldb-check:   [4] = 16
# lldb-check:   [5] = 25
# lldb-check:   [6] = 36
# gdb-check: $2 = Array(Int32) = {0, 1, 4, 9, 16, 25, 36}
debugger
a.unshift 49
# print: *a
# lldb-check: (Array(Int32)){{( \$[0-9]+ =)?  *}}[49, 0, 1, 4, 9, ... (8 total)] {
# lldb-check:   [0] = 49
# lldb-check:   [1] = 0
# lldb-check:   [2] = 1
# lldb-check:   [3] = 4
# lldb-check:   [4] = 9
# lldb-check:   [5] = 16
# lldb-check:   [6] = 25
# lldb-check:   [7] = 36
# gdb-check: $3 = Array(Int32) = {49, 0, 1, 4, 9, 16, 25, 36}
debugger
