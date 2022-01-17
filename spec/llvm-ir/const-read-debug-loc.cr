require "prelude"

class Foo
  def foo
  end
end

def a_foo
  Foo.new
end

THE_FOO.foo
# CHECK:      call %Foo** @"~THE_FOO:read"()
# CHECK-SAME: !dbg [[LOC:![0-9]+]]
# CHECK:      [[LOC]] = !DILocation
# CHECK-SAME: line: 12
# CHECK-SAME: column: 1

THE_FOO = a_foo
