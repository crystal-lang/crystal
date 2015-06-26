require "./lib_pcl"

@[NoInline]
fun get_stack_top : Void*
  dummy :: Int32
  pointerof(dummy) as Void*
end

class Fiber
  STACK_SIZE = 8 * 1024 * 1024

  @@first_fiber = nil
  @@last_fiber = nil
  @@stack_pool = [] of Void*

  protected property :stack_top
  protected property :stack_bottom
  protected property :next_fiber
  protected property :prev_fiber

  def initialize(&@proc)
    @stack = Fiber.allocate_stack
    @stack_top = @stack_bottom = @stack + STACK_SIZE
    @cr = LibPcl.co_create(->(fiber) { (fiber as Fiber).run }, self as Void*, @stack, STACK_SIZE)
    LibPcl.co_set_data(@cr, self as Void*)

    @prev_fiber = nil
    if last_fiber = @@last_fiber
      @prev_fiber = last_fiber
      last_fiber.next_fiber = @@last_fiber = self
    else
      @@first_fiber = @@last_fiber = self
    end
  end

  def initialize
    @cr = LibPcl.co_current
    @proc = ->{}
    @stack = Pointer(Void).null
    @stack_top = get_stack_top
    @stack_bottom = LibGC.stackbottom
    LibPcl.co_set_data(@cr, self as Void*)

    @@first_fiber = @@last_fiber = self
  end

  protected def self.allocate_stack
    @@stack_pool.pop? || LibC.mmap(nil, LibC::SizeT.cast(Fiber::STACK_SIZE),
      LibC::PROT_READ | LibC::PROT_WRITE,
      LibC::MAP_PRIVATE | LibC::MAP_ANON,
      -1, 0)
  end

  def self.stack_pool_collect
    return if @@stack_pool.size == 0
    free_count = @@stack_pool.size > 1 ? @@stack_pool.size / 2 : 1
    free_count.times do
      stack = @@stack_pool.pop
      LibC.munmap(stack, LibC::SizeT.cast(Fiber::STACK_SIZE))
    end
  end

  def run
    @proc.call
    @@stack_pool << @stack

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

    Scheduler.reschedule
  end

  @[NoInline]
  def resume
    Fiber.current.stack_top = get_stack_top

    LibGC.stackbottom = @stack_bottom
    LibPcl.co_call(@cr)
  end

  def self.current
    if current_data = LibPcl.co_get_data(LibPcl.co_current)
      current_data as Fiber
    else
      raise "Could not get the current fiber"
    end
  end

  protected def push_gc_roots
    # Push the used section of the stack
    LibGC.push_all_eager @stack_top, @stack_bottom

    # PCL stores context (setjmp or ucontext) in the first bytes of the given stack
    ptr = @cr as Void*
    # HACK: the size of the context varies on each platform
    LibGC.push_all_eager ptr, ptr + 1024
  end

  @@prev_push_other_roots = LibGC.get_push_other_roots

  # This will push all fibers stacks whenever the GC wants to collect some memory
  LibGC.set_push_other_roots -> do
    @@prev_push_other_roots.call

    fiber = @@first_fiber
    while fiber
      fiber.push_gc_roots
      fiber = fiber.next_fiber
    end
  end

  LibPcl.co_thread_init
  @@root = new

  def self.root
    @@root
  end
end
