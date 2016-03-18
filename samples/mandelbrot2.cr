require "complex"

def mandelbrot(a)
  Iterator.of(a).first(100).reduce(a) { |z, c| z*z + c }
end

(1.0).step(-1, -0.05) do |y|
  (-2.0).step(0.5, 0.0315) do |x|
    print mandelbrot(x + y.i).abs < 2 ? '*' : ' '
  end
  puts
end
