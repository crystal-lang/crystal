class Foo
  def foo
    @@x
    # CHECK:      call i32* @"~Foo+::x:read"
    # CHECK-SAME: !dbg [[LOC:![0-9]+]]
    # CHECK:      [[LOC]] = !DILocation
    # CHECK-SAME: line: [[# @LINE - 4]]
    # CHECK-SAME: column: 5
  end

  @@x = 1
end

class Bar < Foo
end

(Foo.new || Bar.new).foo
