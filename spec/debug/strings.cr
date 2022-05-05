# NOTE: breakpoint on line 1 + next does not work
a = "hello world" # break
# lldb-command: n
# lldb-command: print a
# lldb-check: (String *) $0 = {{0x[0-9a-f]+}} "hello world"
b = 0
