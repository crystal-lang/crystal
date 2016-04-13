# Ported from Rust from https://gist.github.com/joshmarinacci/c84d0979e100d107f685 http://joshondesign.com/2014/09/17/rustlang

record Vector, x : Float64, y : Float64, z : Float64 do
  def scale(s)
    Vector.new(x * s, y * s, z * s)
  end

  def +(other)
    Vector.new(x + other.x, y + other.y, z + other.z)
  end

  def -(other)
    Vector.new(x - other.x, y - other.y, z - other.z)
  end

  def dot(other)
    x*other.x + y*other.y + z*other.z
  end

  def magnitude
    Math.sqrt self.dot(self)
  end

  def normalize
    scale(1.0 / magnitude)
  end
end

record Ray, orig : Vector, dir : Vector

record Color, r : Float64, g : Float64, b : Float64 do
  def scale(s)
    Color.new(r * s, g * s, b * s)
  end

  def +(other)
    Color.new(r + other.r, g + other.g, b + other.b)
  end
end

record Sphere, center : Vector, radius : Float64, color : Color do
  def get_normal(pt)
    (pt - center).normalize
  end
end

record Light, position : Vector, color : Color

record Hit, obj : Sphere, value : Float64

WHITE = Color.new(1.0, 1.0, 1.0)
RED   = Color.new(1.0, 0.0, 0.0)
GREEN = Color.new(0.0, 1.0, 0.0)
BLUE  = Color.new(0.0, 0.0, 1.0)

LIGHT1 = Light.new(Vector.new(0.7, -1.0, 1.7), WHITE)

def shade_pixel(ray, obj, tval)
  pi = ray.orig + ray.dir.scale(tval)
  color = diffuse_shading pi, obj, LIGHT1
  col = (color.r + color.g + color.b) / 3.0
  (col * 6.0).to_i
end

def intersect_sphere(ray, center, radius)
  l = center - ray.orig
  tca = l.dot(ray.dir)
  if tca < 0.0
    return nil
  end

  d2 = l.dot(l) - tca*tca
  r2 = radius*radius
  if d2 > r2
    return nil
  end

  thc = Math.sqrt(r2 - d2)
  t0 = tca - thc
  # t1 = tca + thc
  if t0 > 10_000
    return nil
  end

  t0
end

def clamp(x, a, b)
  return a if x < a
  return b if x > b
  x
end

def diffuse_shading(pi, obj, light)
  n = obj.get_normal(pi)
  lam1 = (light.position - pi).normalize.dot(n)
  lam2 = clamp lam1, 0.0, 1.0
  light.color.scale(lam2*0.5) + obj.color.scale(0.3)
end

puts "Hello, worlds!"

lut = %w(. - + * X M)
w = 20 * 4
h = 10 * 4

scene = [
  Sphere.new(Vector.new(-1.0, 0.0, 3.0), 0.3, RED),
  Sphere.new(Vector.new(0.0, 0.0, 3.0), 0.8, GREEN),
  Sphere.new(Vector.new(1.0, 0.0, 3.0), 0.4, BLUE),
]

(0...h).each do |j|
  puts "--"
  (0...w).each do |i|
    fw, fi, fj, fh = w.to_f, i.to_f, j.to_f, h.to_f

    ray = Ray.new(
      Vector.new(0.0, 0.0, 0.0),
      Vector.new((fi - fw/2.0)/fw, (fj - fh/2.0)/fh, 1.0).normalize
    )

    hit = nil

    scene.each do |obj|
      ret = intersect_sphere(ray, obj.center, obj.radius)
      if ret
        hit = Hit.new obj, ret
      end
    end

    if hit
      pixel = lut[shade_pixel(ray, hit.obj, hit.value)]
    else
      pixel = " "
    end

    print pixel
  end
end

puts "we are done!"
