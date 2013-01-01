require "complex"

def mandelbrot(a)
  Array.new(100, a).inject(a) { |z, c| z*z + c }
end

(1.0).step(-1, -0.05) do |y|
  (-2.0).step(0.5, 0.0315) do |x|
    C.putchar mandelbrot(Complex.new(x, y)).abs < 2 ? '*' : ' '
  end
  puts
end
