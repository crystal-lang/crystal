require "prelude"

class Foo
  def foo
    @@x
    # CHECK:      call %String** @"~Bar::x:read"
    # CHECK-SAME: !dbg [[LOC:![0-9]+]]
    # CHECK:      [[LOC]] = !DILocation
    # CHECK-SAME: line: [[# @LINE - 4]]
    # CHECK-SAME: column: 5
  end

  @@x = ""
end

class Bar < Foo
end

Bar.new.foo
