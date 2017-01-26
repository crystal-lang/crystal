private class A
  def initialize
  end

  def []=(x, y)
    puts "#{x.inspect} => #{y.inspect}"
  end
end

A{1 => 2, 3 => 4}
