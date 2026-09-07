# print: a
# lldb-check: (int) {{(\$[0-9]+ = )?}}0
# gdb-check: $1 = 0
debugger
a = 42
# print: a
# lldb-check: (int) {{(\$[0-9]+ = )?}}42
# gdb-check: $2 = 42
debugger
