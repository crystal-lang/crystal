# lldb-command: print a
# lldb-check: (int) $0 = 0
debugger
a = 42
# lldb-command: print a
# lldb-check: (int) $1 = 42
debugger
