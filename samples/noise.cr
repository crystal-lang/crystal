# Perlin noise benchmark: https://github.com/nsf/pnoise

record Vec2, x : Float64, y : Float64

def lerp(a, b, v)
  a * (1.0 - v) + b * v
end

def smooth(v)
  v * v * (3.0 - 2.0 * v)
end

def random_gradient
  v = rand * Math::PI * 2.0
  Vec2.new(Math.cos(v), Math.sin(v))
end

def gradient(orig, grad, p)
  sp = Vec2.new(p.x - orig.x, p.y - orig.y)
  grad.x * sp.x + grad.y * sp.y
end

struct Noise2DContext
  def initialize
    @rgradients = StaticArray(Vec2, 256).new { random_gradient }
    @permutations = StaticArray(Int32, 256).new { |i| i }
    @permutations.shuffle!
  end

  def get_gradient(x, y)
    idx = @permutations[x & 255] + @permutations[y & 255]
    @rgradients[idx & 255]
  end

  def get_gradients(x, y)
    x0f = x.floor
    y0f = y.floor
    x0 = x0f.to_i
    y0 = y0f.to_i
    x1 = x0 + 1
    y1 = y0 + 1

    {
      {
        get_gradient(x0, y0),
        get_gradient(x1, y0),
        get_gradient(x0, y1),
        get_gradient(x1, y1),
      },
      {
        Vec2.new(x0f + 0.0, y0f + 0.0),
        Vec2.new(x0f + 1.0, y0f + 0.0),
        Vec2.new(x0f + 0.0, y0f + 1.0),
        Vec2.new(x0f + 1.0, y0f + 1.0),
      },
    }
  end

  def get(x, y)
    p = Vec2.new(x, y)
    gradients, origins = get_gradients(x, y)
    v0 = gradient(origins[0], gradients[0], p)
    v1 = gradient(origins[1], gradients[1], p)
    v2 = gradient(origins[2], gradients[2], p)
    v3 = gradient(origins[3], gradients[3], p)
    fx = smooth(x - origins[0].x)
    vx0 = lerp(v0, v1, fx)
    vx1 = lerp(v2, v3, fx)
    fy = smooth(y - origins[0].y)
    lerp(vx0, vx1, fy)
  end
end

symbols = [' ', '░', '▒', '▓', '█', '█']
pixels = Array.new(256) { Array.new(256, 0.0) }

n2d = Noise2DContext.new

100.times do |i|
  256.times do |y|
    256.times do |x|
      v = n2d.get(x * 0.1, (y + (i * 128)) * 0.1) * 0.5 + 0.5
      pixels[y][x] = v
    end
  end
end

256.times do |y|
  256.times do |x|
    v = pixels[y][x]
    print(symbols[(v / 0.2).to_i])
  end
  puts
end
