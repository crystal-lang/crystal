# Ported from Nimrod: https://gist.github.com/AdrianV/5774141

require "./sdl/sdl"

WIDTH     = 1280
HEIGHT    =  720
FOV       = 45.0
MAX_DEPTH =    6

struct Vec3
  getter :x
  getter :y
  getter :z

  def initialize
    @x, @y, @z = 0.0, 0.0, 0.0
  end

  def initialize(value)
    @x, @y, @z = value, value, value
  end

  def initialize(@x, @y, @z)
  end

  {% for op in %w(+ - * /) %}
    def {{ op.id }}(other : Vec3)
      Vec3.new(@x {{ op.id }} other.x, @y {{ op.id }} other.y, @z {{ op.id }} other.z)
    end

    def {{ op.id }}(other : Float)
      Vec3.new(@x {{ op.id }} other, @y {{ op.id }} other, @z {{ op.id }} other)
    end
  {% end %}

  def -
    Vec3.new(-@x, -@y, -@z)
  end

  def dot(other)
    @x * other.x + @y * other.y + @z * other.z
  end

  def magnitude
    Math.sqrt(dot(self))
  end

  def normalize
    m = magnitude
    Vec3.new(@x / m, @y / m, @z / m)
  end
end

record Ray, start : Vec3, dir : Vec3

class Sphere
  getter :color
  getter :reflection
  getter :transparency

  def initialize(@center : Vec3, @radius : Float64, @color : Vec3, @reflection = 0.0, @transparency = 0.0)
  end

  def intersects?(ray)
    vl = @center - ray.start
    a = vl.dot(ray.dir)
    return false if a < 0

    b2 = vl.dot(vl) - a * a
    r2 = @radius * @radius
    return false if b2 > r2

    true
  end

  def intersect(ray, distance)
    vl = @center - ray.start
    a = vl.dot(ray.dir)
    return nil if a < 0

    b2 = vl.dot(vl) - a * a
    r2 = @radius * @radius
    return nil if b2 > r2

    c = Math.sqrt(r2 - b2)
    near = a - c
    far = a + c
    near < 0 ? far : near
  end

  def normalize(v)
    (v - @center).normalize
  end
end

record Light, position : Vec3, color : Vec3
record Scene, objects : Array(Sphere), lights : Array(Light)

def trace(ray, scene, depth)
  nearest = 1e9
  obj = nil
  result = Vec3.new

  scene.objects.each do |o|
    distance = 1e9
    if (distance = o.intersect(ray, distance)) && distance < nearest
      nearest = distance
      obj = o
    end
  end

  if obj
    point_of_hit = ray.dir * nearest
    point_of_hit += ray.start
    normal = obj.normalize(point_of_hit)
    inside = false
    dot_normal_ray = normal.dot(ray.dir)
    if dot_normal_ray > 0
      inside = true
      normal = -normal
      dot_normal_ray = -dot_normal_ray
    end

    reflection_ratio = obj.reflection
    norm_e5 = normal * 1.0e-5

    scene.lights.each do |lgt|
      light_direction = (lgt.position - point_of_hit).normalize
      r = Ray.new(point_of_hit + norm_e5, light_direction)

      # go through the scene check whether we're blocked from the lights
      blocked = scene.objects.any? &.intersects? r

      unless blocked
        temp = lgt.color
        temp *= Math.max(0.0, normal.dot(light_direction))
        temp *= obj.color
        temp *= (1.0 - reflection_ratio)
        result += temp
      end
    end

    facing = Math.max(0.0, -dot_normal_ray)
    fresneleffect = reflection_ratio + (1.0 - reflection_ratio) * ((1.0 - facing) ** 5.0)

    # compute reflection
    if depth < MAX_DEPTH && reflection_ratio > 0
      reflection_direction = ray.dir - normal * 2.0 * dot_normal_ray
      reflection = trace(Ray.new(point_of_hit + norm_e5, reflection_direction), scene, depth + 1)
      result += reflection * fresneleffect
    end

    # compute refraction
    if depth < MAX_DEPTH && (obj.transparency > 0.0)
      ior = 1.5
      ce = ray.dir.dot(normal) * -1.0
      ior = inside ? 1.0 / ior : ior
      eta = 1.0 / ior
      gf = (ray.dir + normal * ce) * eta
      sin_t1_2 = 1.0 - ce * ce
      sin_t2_2 = sin_t1_2 * (eta * eta)
      if sin_t2_2 < 1.0
        gc = normal * Math.sqrt(1 - sin_t2_2)
        refraction_direction = gf - gc
        refraction = trace(Ray.new(point_of_hit - normal * 1.0e-4, refraction_direction),
          scene, depth + 1)
        result += refraction * (1.0 - fresneleffect) * obj.transparency
      end
    end
  end

  result
end

def render(scene, surface)
  surface.lock

  eye = Vec3.new
  h = Math.tan(FOV / 360.0 * 2.0 * Math::PI / 2.0) * 2.0
  ww = surface.width.to_f64
  hh = surface.height.to_f64
  w = h * ww / hh

  i = 0
  HEIGHT.times do |y|
    yy = y.to_f64
    WIDTH.times do |x|
      xx = x.to_f64
      dir = Vec3.new((xx - ww / 2.0) / ww * w,
        (hh / 2.0 - yy) / hh * h,
        -1.0).normalize
      pixel = trace(Ray.new(eye, dir), scene, 0.0)
      r = Math.min(255, (pixel.x * 255.0).round.to_i)
      g = Math.min(255, (pixel.y * 255.0).round.to_i)
      b = Math.min(255, (pixel.z * 255.0).round.to_i)
      surface[i] = (b << 24) + (g << 16) + (r << 8)
      i += 1
    end
  end

  surface.unlock
  surface.update_rect 0, 0, 0, 0
end

Process.on_interrupt { exit }

scene = Scene.new(
  [
    Sphere.new(Vec3.new(0.0, -10002.0, -20.0), 10000.0, Vec3.new(0.8, 0.8, 0.8)),
    Sphere.new(Vec3.new(0.0, 2.0, -20.0), 4.0, Vec3.new(0.8, 0.5, 0.5), 0.5),
    Sphere.new(Vec3.new(5.0, 0.0, -15.0), 2.0, Vec3.new(0.3, 0.8, 0.8), 0.2),
    Sphere.new(Vec3.new(-5.0, 0.0, -15.0), 2.0, Vec3.new(0.3, 0.5, 0.8), 0.2),
    Sphere.new(Vec3.new(-2.0, -1.0, -10.0), 1.0, Vec3.new(0.1, 0.1, 0.1), 0.1, 0.8),
  ],
  [
    Light.new(Vec3.new(-10.0, 20.0, 30.0), Vec3.new(2.0, 2.0, 2.0)),
  ]
)

SDL.init
SDL.hide_cursor
surface = SDL.set_video_mode WIDTH, HEIGHT, 32, LibSDL::DOUBLEBUF | LibSDL::HWSURFACE | LibSDL::ASYNCBLIT

first = true

begin
  while true
    SDL.poll_events do |event|
      if event.type.in?(LibSDL::QUIT, LibSDL::KEYDOWN)
        SDL.quit
        exit
      end
    end

    if first
      start = SDL.ticks
      render scene, surface
      ms = SDL.ticks - start
      puts "Rendered in #{ms} ms"
      first = false
    end
  end
ensure
  SDL.quit
end
