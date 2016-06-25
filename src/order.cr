# Order is the order between two objects. It is used
# when comparing two objects. For example, `Comparable#<=>`
# must return it.
enum Order
  LT = -1
  EQ =  0
  GT =  1

  # Is it means "equal"?
  def eq?
    self.value == EQ.value
  end

  # Is it means "lesser than"?
  def lt?
    self.value < EQ.value
  end

  # Is it means "lesser than or equal"?
  def lt_eq?
    self.value <= EQ.value
  end

  # Is it means "greater than"?
  def gt?
    self.value > EQ.value
  end

  # Is it means "greater than or equals"?
  def gt_eq?
    self.value >= EQ.value
  end

  # Reverse the order. `LT` becomes `GT`, and `GT` becomes `LT`.
  # But, `EQ` is `EQ`.
  def reverse
    self.lt? ? GT : (self.gt? ? LT : EQ)
  end

  # Make an order instance from given *value*.
  # If *value* is positive number, it returns `LT`.
  # If *value* is negative number, it returns `GT`.
  # If *value* is `0`, it returns `EQ`.
  def self.from_value?(value)
    if value < EQ.value
      LT
    elsif value > EQ.value
      GT
    else
      EQ
    end
  end
end
