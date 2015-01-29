@[Link("pcl")]
lib Pcl
  type Coroutine = Void*

  fun co_thread_init : Int32
  fun co_create(func : (Void* ->), data : Void*, stack : Void*, size : Int32) : Coroutine
  fun co_call(cr : Coroutine)
  fun co_resume
  fun co_current : Coroutine
  fun co_get_data(cr : Coroutine) : Void*
  fun co_set_data(cr : Coroutine, data : Void*) : Void*
end

@[NoInline]
fun get_stack_top : Void*
  dummy :: Int32
  pointerof(dummy) as Void*
end

class Fiber
  STACK_SIZE = 8 * 1024 * 1024

  @@main_stackbottom = LibGC.stackbottom
  @@main_stacktop = get_stack_top
  @@first_fiber = nil
  @@last_fiber = nil

  protected property :stack_top
  protected property :stack_bottom
  protected property :next_fiber
  protected property :prev_fiber

  def initialize(&@proc)
    @stack = LibC.malloc(STACK_SIZE.to_u32)
    @stack_top = @stack_bottom = @stack + STACK_SIZE
    @cr = Pcl.co_create(->(fiber) { (fiber as Fiber).run }, self as Void*, @stack, STACK_SIZE)
    Pcl.co_set_data(@cr, self as Void*)

    @prev_fiber = nil
    if last_fiber = @@last_fiber
      @prev_fiber = last_fiber
      last_fiber.next_fiber = @@last_fiber = self
    else
      @@first_fiber = @@last_fiber = self
    end
  end

  def run
    @arg = @proc.call
    LibC.free(@stack)

    # Remove the current fiber from the linked list

    if prev_fiber = @prev_fiber
      prev_fiber.next_fiber = @next_fiber
    else
      @@first_fiber = @next_fiber
    end

    if next_fiber = @next_fiber
      next_fiber.prev_fiber = @prev_fiber
    else
      @@last_fiber = @prev_fiber
    end
  end

  @[NoInline]
  def resume(@arg = nil)
    if fiber = Fiber.current
      fiber.stack_top = get_stack_top
    else
      @@main_stacktop = get_stack_top
    end

    prev_stackbottom = LibGC.stackbottom
    LibGC.stackbottom = @stack_bottom
    Pcl.co_call(@cr)
    LibGC.stackbottom = prev_stackbottom
    @arg
  end

  def yield(@arg = nil)
    @stack_top = get_stack_top
    Pcl.co_resume
    @arg
  end

  def self.yield(arg = nil)
    current.not_nil!.yield(arg)
  end

  def self.current
    if current_data = Pcl.co_get_data(Pcl.co_current)
      current_data as Fiber
    else
      nil
    end
  end

  @@prev_push_other_roots = LibGC.get_push_other_roots

  # This will push all fibers stacks whenever the GC wants to collect some memory
  LibGC.set_push_other_roots -> do
    @@prev_push_other_roots.call

    fiber = @@first_fiber
    while fiber
      LibGC.push_all fiber.stack_top, fiber.stack_bottom
      fiber = fiber.next_fiber
    end

    LibGC.push_all @@main_stacktop, @@main_stackbottom
  end

  Pcl.co_thread_init
end
