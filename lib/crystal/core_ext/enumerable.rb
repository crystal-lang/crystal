module Enumerable
  def at(index)
    each_with_index.find{ |obj, i| i == index}.first
  end
end