class Foo
  property lorem : Int32?

  def foo
    1
  end
end

class Bar
  def foo
    2
  end
end

def bar(o)
  while false
    o.foo
  end
end

def baz(o)
  o.foo
end

puts bar(Foo.new)
puts bar(Bar.new)
puts baz(Foo.new)

Foo.new.lorem

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:16:8
#
# 2 implementations found
# .../samples/impl.cr:3:3
# .../samples/impl.cr:9:3

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:21:5
#
# 1 implementation found
# .../samples/impl.cr:3:3

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:24:7
#
# 1 implementation found
# .../samples/impl.cr:14:1

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:26:3
#
# 1 implementation found
# .../src/kernel.cr:67:1

# ./crystal tool implementations samples/impl.cr --cursor samples/impl.cr:28:9
#
# 1 implementation found
# .../samples/impl.cr:2:3
#  ~> macro property: .../src/object.cr:364:5
#  ~> macro getter: .../src/object.cr:207:7
