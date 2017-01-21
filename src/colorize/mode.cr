@[Flags]
enum Colorize::Mode
  Bold      = 1 << 0
  Bright    = Bold
  Dim       = 1 << 1
  Underline = 1 << 3
  Blink     = 1 << 4
  Reverse   = 1 << 6
  Hidden    = 1 << 7

  def codes
    8.times do |i|
      yield i + 1 unless value & (1 << i) == 0
    end
  end
end
