module Crypto::Subtle
  # Compares *x* and *y* in constant time and returns true if they are the same, and false if they are not.
  # Note: *x* and *y* must be able to respond to `to_slice`.
  #
  # ```
  # Crypto::Suble.constant_time_compare("foo","bar") => false
  # Crypto::Suble.constant_time_compare("foo","foo") => true
  # ```
  def self.constant_time_compare(x, y)
    x = x.to_slice
    y = y.to_slice
    return false if x.size != y.size

    v = 0_u8

    x.size.times do |i|
      v |= x[i] ^ y[i]
    end

    constant_time_byte_eq(v, 0) == 1
  end

  def self.constant_time_byte_eq(x, y)
    z = ~(x ^ y)
    z &= z >> 4
    z &= z >> 2
    z &= z >> 1
    z
  end
end
