module Enumerable
  def at(index)
    index.times { self.next }
    self.next
  end
end