# NOTE: breakpoint on line 1 + next does not work
a = 42 # break
# lldb-command: print a
# lldb-check: (int) $0 = 0
# lldb-command: n
# lldb-command: print a
# lldb-check: (int) $1 = 42
b = 0
