class A
  def foo
    1
  end
end

class B
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

puts bar(A.new)
puts bar(B.new)
puts baz(A.new)


# ./crystal implementations samples/impl.cr --cursor samples/impl.cr:15:8
#
# .../samples/impl.cr:2:3
# .../samples/impl.cr:8:3

# ./crystal implementations samples/impl.cr --cursor samples/impl.cr:20:5
#
# .../samples/impl.cr:2:3

# ./crystal implementations samples/impl.cr --cursor samples/impl.cr:23:7
#
# .../samples/impl.cr:13:1

# ./crystal implementations samples/impl.cr --cursor samples/impl.cr:25:3
#
# .../src/kernel.cr:67:1
