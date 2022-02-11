["hello world"].each do |v|
  a = v
  b = 0 # break
  # lldb-command: print a
  # lldb-check: (String *) $0 = {{0x[0-9a-f]+}} "hello world"
  # lldb-command: print v
  # lldb-check: (String *) $1 = {{0x[0-9a-f]+}} "hello world"
end
