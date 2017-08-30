require "c/sys/mman"

# :nodoc:
@[NoInline]
fun _fiber_get_stack_top : Void*
  dummy = uninitialized Int32
  pointerof(dummy).as(Void*)
end

class Fiber
  STACK_SIZE = 8 * 1024 * 1024

  @@first_fiber : Fiber? = nil
  @@last_fiber : Fiber? = nil
  @@stack_pool = [] of Void*

  @stack : Void*
  @resume_event : Event::Event?
  @stack_top = uninitialized Void*
  protected property stack_top : Void*
  protected property stack_bottom : Void*
  protected property next_fiber : Fiber?
  protected property prev_fiber : Fiber?
  property name : String?

  def initialize(@name : String? = nil, &@proc : ->)
    @stack = Fiber.allocate_stack
    @stack_bottom = @stack + STACK_SIZE
    fiber_main = ->(f : Fiber) { f.run }

    stack_ptr = @stack_bottom - sizeof(Void*)

    # Align the stack pointer to 16 bytes
    stack_ptr = Pointer(Void*).new(stack_ptr.address & ~0x0f_u64)

    # @stack_top will be the stack pointer on the initial call to `resume`
    {% if flag?(:x86_64) %}
      # In x86-64, the context switch push/pop 7 registers
      @stack_top = (stack_ptr - 7).as(Void*)

      stack_ptr[0] = fiber_main.pointer # Initial `resume` will `ret` to this address
      stack_ptr[-1] = self.as(Void*)    # This will be `pop` into %rdi (first argument)
    {% elsif flag?(:i686) %}
      # In IA32, the context switch push/pops 4 registers.
      # Add two more to store the argument of `fiber_main`
      @stack_top = (stack_ptr - 6).as(Void*)

      stack_ptr[0] = self.as(Void*)      # First argument passed on the stack
      stack_ptr[-1] = Pointer(Void).null # Empty space to keep the stack alignment (16 bytes)
      stack_ptr[-2] = fiber_main.pointer # Initial `resume` will `ret` to this address
    {% elsif flag?(:aarch64) %}
      # In ARMv8, the context switch push/pops 12 registers + 8 FPU registers.
      # Add one more to store the argument of `fiber_main` (+ alignment)
      @stack_top = (stack_ptr - 22).as(Void*)
      stack_ptr[-2] = self.as(Void*)      # This will be `pop` into r0 (first argument)
      stack_ptr[-14] = fiber_main.pointer # Initial `resume` will `ret` to this address
    {% elsif flag?(:arm) %}
      # In ARMv6 / ARVMv7, the context switch push/pops 8 registers.
      # Add one more to store the argument of `fiber_main`
      {% if flag?(:armhf) %}
        # Add 8 FPU registers.
        @stack_top = (stack_ptr - (9 + 16)).as(Void*)
      {% else %}
        @stack_top = (stack_ptr - 9).as(Void*)
      {% end %}

      stack_ptr[0] = fiber_main.pointer # Initial `resume` will `ret` to this address
      stack_ptr[-9] = self.as(Void*)    # This will be `pop` into r0 (first argument)
    {% else %}
      {{ raise "Unsupported platform, only x86_64 and i686 are supported." }}
    {% end %}

    @prev_fiber = nil
    if last_fiber = @@last_fiber
      @prev_fiber = last_fiber
      last_fiber.next_fiber = @@last_fiber = self
    else
      @@first_fiber = @@last_fiber = self
    end
  end

  def initialize
    @proc = Proc(Void).new { }
    @stack = Pointer(Void).null
    @stack_top = _fiber_get_stack_top
    @stack_bottom = LibGC.stackbottom
    @name = "main"

    @@first_fiber = @@last_fiber = self
  end

  protected def self.allocate_stack
    @@stack_pool.pop? || LibC.mmap(nil, Fiber::STACK_SIZE,
      LibC::PROT_READ | LibC::PROT_WRITE,
      LibC::MAP_PRIVATE | LibC::MAP_ANON,
      -1, 0
    ).tap do |pointer|
      raise Errno.new("Cannot allocate new fiber stack") if pointer == LibC::MAP_FAILED
      {% if flag?(:linux) %}
        LibC.madvise(pointer, Fiber::STACK_SIZE, LibC::MADV_NOHUGEPAGE)
      {% end %}
      LibC.mprotect(pointer, 4096, LibC::PROT_NONE)
    end
  end

  def self.stack_pool_collect
    return if @@stack_pool.size == 0
    free_count = @@stack_pool.size > 1 ? @@stack_pool.size / 2 : 1
    free_count.times do
      stack = @@stack_pool.pop
      LibC.munmap(stack, Fiber::STACK_SIZE)
    end
  end

  def run
    @proc.call
  rescue ex
    if name = @name
      STDERR.puts "Unhandled exception in spawn(name: #{name}):"
    else
      STDERR.puts "Unhandled exception in spawn:"
    end
    ex.inspect_with_backtrace STDERR
    STDERR.flush
  ensure
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

    # Delete the resume event if it was used by `yield` or `sleep`
    @resume_event.try &.free

    Scheduler.reschedule
  end

  @[NoInline]
  @[Naked]
  protected def self.switch_stacks(current, to) : Nil
    {% if flag?(:x86_64) %}
      asm("
        pushq %rdi
        pushq %rbx
        pushq %rbp
        pushq %r12
        pushq %r13
        pushq %r14
        pushq %r15
        movq %rsp, ($0)
        movq ($1), %rsp
        popq %r15
        popq %r14
        popq %r13
        popq %r12
        popq %rbp
        popq %rbx
        popq %rdi"
              :: "r"(current), "r"(to))
    {% elsif flag?(:i686) %}
      asm("
        pushl %edi
        pushl %ebx
        pushl %ebp
        pushl %esi
        movl %esp, ($0)
        movl ($1), %esp
        popl %esi
        popl %ebp
        popl %ebx
        popl %edi"
              :: "r"(current), "r"(to))
    {% elsif flag?(:aarch64) %}
      # Adapted from https://github.com/ldc-developers/druntime/blob/ldc/src/core/threadasm.S
      #
      # preserve/restore AAPCS64 registers
      # x19-x28   5.1.1 64-bit callee saved
      # x29       fp, or possibly callee saved reg - depends on platform choice 5.2.3)
      # x30       lr
      # x0        self argument (initial call)
      # d8-d15    5.1.2 says callee only must save bottom 64-bits (the "d" regs)
      asm("
        stp     d15, d14, [sp, #-22*8]!
        stp     d13, d12, [sp, #2*8]
        stp     d11, d10, [sp, #4*8]
        stp     d9,  d8,  [sp, #6*8]
        stp     x30, x29, [sp, #8*8]  // lr, fp
        stp     x28, x27, [sp, #10*8]
        stp     x26, x25, [sp, #12*8]
        stp     x24, x23, [sp, #14*8]
        stp     x22, x21, [sp, #16*8]
        stp     x20, x19, [sp, #18*8]
        stp     x0,  x1,  [sp, #20*8] // self, alignment

        mov     x19, sp
        str     x19, [$0]
        mov     sp, $1

        ldp     x0,  x1,  [sp, #20*8] // self, alignment
        ldp     x20, x19, [sp, #18*8]
        ldp     x22, x21, [sp, #16*8]
        ldp     x24, x23, [sp, #14*8]
        ldp     x26, x25, [sp, #12*8]
        ldp     x28, x27, [sp, #10*8]
        ldp     x30, x29, [sp, #8*8]  // lr, fp
        ldp     d9,  d8,  [sp, #6*8]
        ldp     d11, d10, [sp, #4*8]
        ldp     d13, d12, [sp, #2*8]
        ldp     d15, d14, [sp], #22*8

        // avoid a stack corruption that will confuse the unwinder
        mov     x16, x30 // save lr
        mov     x30, #0  // reset lr
        br      x16      // jump to new pc value
        "
              :: "r"(current), "r"(to))
    {% elsif flag?(:armhf) %}
      # we eventually reset LR to zero to avoid the ARM unwinder to mistake the
      # context switch as a regular call.
      asm("
        .fpu vfp
        stmdb  sp!, {r0, r4-r11, lr}
        vstmdb sp!, {d8-d15}
        str    sp, [$0]
        ldr    sp, [$1]
        vldmia sp!, {d8-d15}
        ldmia  sp!, {r0, r4-r11, lr}
        mov    r1, lr
        mov    lr, #0
        mov    pc, r1
        "
              :: "r"(current), "r"(to))
    {% elsif flag?(:arm) %}
      # we eventually reset LR to zero to avoid the ARM unwinder to mistake the
      # context switch as a regular call.
      asm("
        stmdb  sp!, {r0, r4-r11, lr}
        str    sp, [$0]
        ldr    sp, [$1]
        ldmia  sp!, {r0, r4-r11, lr}
        mov    r1, lr
        mov    lr, #0
        mov    pc, r1
        "
              :: "r"(current), "r"(to))
    {% end %}
  end

  def resume : Nil
    current, Thread.current.current_fiber = Thread.current.current_fiber, self
    LibGC.stackbottom = @stack_bottom
    {% if flag?(:aarch64) %}
      Fiber.switch_stacks(pointerof(current.@stack_top), @stack_top)
    {% else %}
      Fiber.switch_stacks(pointerof(current.@stack_top), pointerof(@stack_top))
    {% end %}
  end

  def sleep(time : Time::Span)
    event = @resume_event ||= Scheduler.create_resume_event(self)
    event.add(time)
    Scheduler.reschedule
  end

  def sleep(time : Number)
    sleep(time.seconds)
  end

  def yield
    sleep(0)
  end

  def self.sleep(time)
    Fiber.current.sleep(time)
  end

  def self.yield
    Fiber.current.yield
  end

  def to_s(io)
    io << "#<" << self.class.name << ":0x"
    object_id.to_s(16, io)
    if name = @name
      io << ": " << name
    end
    io << ">"
  end

  def inspect(io)
    to_s(io)
  end

  protected def push_gc_roots
    # Push the used section of the stack
    LibGC.push_all_eager @stack_top, @stack_bottom
  end

  @@root = new

  def self.root : self
    @@root
  end

  Thread.current.current_fiber = root

  def self.current : self
    Thread.current.current_fiber
  end

  @@prev_push_other_roots = LibGC.get_push_other_roots

  # This will push all fibers stacks whenever the GC wants to collect some memory
  LibGC.set_push_other_roots ->do
    @@prev_push_other_roots.call

    fiber = @@first_fiber
    while fiber
      fiber.push_gc_roots unless fiber == Thread.current.current_fiber
      fiber = fiber.next_fiber
    end
  end
end
