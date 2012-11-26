module Enumerable
  def map
    ary = []
    each { |e| ary << yield e }
    ary
  end

  def select
    ary = []
    each { |e| ary << e if yield e }
    ary
  end
end