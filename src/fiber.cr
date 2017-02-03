require "c/sys/mman"

# :nodoc:
@[NoInline]
fun _fiber_get_stack_top : Void*
  dummy = uninitialized Int32
  pointerof(dummy).as(Void*)
end

require "ck/lib_ck"

class Fiber
  STACK_SIZE = 8 * 1024 * 1024

  @@first_fiber : Fiber? = nil
  @@last_fiber : Fiber? = nil
  @@stack_pool = [] of Void*
  @@stack_pool_mutex = SpinLock.new
  @@fiber_list_mutex = SpinLock.new
  @thread : Void*
  @callback : (->)?

  # @@gc_lock = LibCK.rwlock_init
  @@gc_lock = LibCK.brlock_init
  @[ThreadLocal]
  @@gc_lock_reader = LibCK.brlock_reader_init

  @stack : Void*
  @resume_event : Event::Event?
  @stack_top = uninitialized Void*
  protected property stack_top : Void*
  protected property stack_bottom : Void*
  protected property next_fiber : Fiber?
  protected property prev_fiber : Fiber?
  property name : String?

  def initialize(@name : String? = nil, &@proc : ->)
    @thread = Pointer(Void).null
    @stack = Fiber.allocate_stack
    @stack_bottom = @stack + STACK_SIZE
    fiber_main = ->(f : Fiber) { f.run }

    stack_ptr = @stack + STACK_SIZE - sizeof(Void*)

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

    Fiber.gc_read_lock
    @@fiber_list_mutex.synchronize do
      if last_fiber = @@last_fiber
        @prev_fiber = last_fiber
        last_fiber.next_fiber = @@last_fiber = self
      else
        @@first_fiber = @@last_fiber = self
      end
    end
    Fiber.gc_read_unlock
  end

  def initialize
    @proc = Proc(Void).new { }
    @name = "main #{LibC.pthread_self.address}"
    @thread = LibC.pthread_self.as(Void*)
    @stack = Pointer(Void).null
    @stack_top = _fiber_get_stack_top
    @stack_bottom = LibGC.get_stackbottom

    Fiber.gc_register_thread

    Fiber.gc_read_lock
    @@fiber_list_mutex.synchronize do
      if last_fiber = @@last_fiber
        @prev_fiber = last_fiber
        last_fiber.next_fiber = @@last_fiber = self
      else
        @@first_fiber = @@last_fiber = self
      end
    end
    Fiber.gc_read_unlock
  end

  def name!
    name || "?"
  end

  protected def self.allocate_stack
    @@stack_pool_mutex.synchronize { @@stack_pool.pop? } || LibC.mmap(nil, Fiber::STACK_SIZE,
      LibC::PROT_READ | LibC::PROT_WRITE,
      LibC::MAP_PRIVATE | LibC::MAP_ANON,
      -1, 0).tap do |pointer|
      raise Errno.new("Cannot allocate new fiber stack") if pointer == LibC::MAP_FAILED
      {% if flag?(:linux) %}
        LibC.madvise(pointer, Fiber::STACK_SIZE, LibC::MADV_NOHUGEPAGE)
      {% end %}
      LibC.mprotect(pointer, 4096, LibC::PROT_NONE)
    end
  end

  def self.stack_pool_collect
    @@stack_pool_mutex.synchronize do
      return if @@stack_pool.size == 0
      free_count = @@stack_pool.size > 1 ? @@stack_pool.size / 2 : 1
      free_count.times do
        stack = @@stack_pool.pop
        LibC.munmap(stack, Fiber::STACK_SIZE)
      end
    end
  end

  def run
    Fiber.gc_read_unlock
    log "Start with callback %ld", @callback
    flush_callback
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
    # LibC.printf "bye\n"

    set_callback

    # Delete the resume event if it was used by `yield` or `sleep`
    @resume_event.try &.free
    @resume_event = nil

    Scheduler.current.reschedule
  end

  def set_callback
    @callback = ->{
      @@stack_pool_mutex.synchronize { @@stack_pool << @stack }

      # Remove the current fiber from the linked list
      Fiber.gc_read_lock
      @@fiber_list_mutex.synchronize do
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
      Fiber.gc_read_unlock

      nil
    }
  end

  protected def self.gc_register_thread
    LibCK.brlock_read_register pointerof(@@gc_lock), pointerof(@@gc_lock_reader)
  end

  @[NoInline]
  protected def self.gc_read_lock
    # log2 "gc_read_lock begin"
    # LibCK.rwlock_read_lock pointerof(@@gc_lock)
    LibCK.brlock_read_lock pointerof(@@gc_lock), pointerof(@@gc_lock_reader)
    # log2 "gc_read_lock end"
  end

  @[NoInline]
  protected def self.gc_read_unlock
    # log2 "gc_read_unlock begin"
    # LibCK.rwlock_read_unlock pointerof(@@gc_lock)
    LibCK.brlock_read_unlock pointerof(@@gc_lock_reader)
    # log2 "gc_read_unlock end"
  end

  @[NoInline]
  protected def self.gc_write_lock
    # log2 "gc_write_lock begin"
    # LibCK.rwlock_write_lock pointerof(@@gc_lock)
    LibCK.brlock_write_lock pointerof(@@gc_lock)
    # log2 "gc_write_lock end"
  end

  @[NoInline]
  protected def self.gc_write_unlock
    # log2 "gc_write_unlock begin"
    # LibCK.rwlock_write_unlock pointerof(@@gc_lock)
    LibCK.brlock_write_unlock pointerof(@@gc_lock)
    # log2 "gc_write_unlock end"
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

  protected def thread=(@thread)
  end

  def resume
    # The purpose of this method is to resume a fiber (F1) and give control back
    # to another one (F2).
    log "Resume '%s' -> '%s'", Fiber.current.name!, self.name!
    Fiber.gc_read_lock

    # current <~~ F1
    # self    <~~ F2
    current = Thread.current.current_fiber

    # F1's resume callback is now stored in F2's @callback instance variable.
    @callback = current.transfer_callback

    # LibGC.set_stackbottom LibPThread.self as Void*, @stack_bottom

    # Tell F2 that it will be running in the current thread, and tell the thread
    # that it will be running F2.
    Thread.current.current_fiber = self
    self.thread = LibC.pthread_self.as(Void*)

    # F1 will be suspended, therefore it won't be assigned to any execution thread.
    current.thread = Pointer(Void).null

    # Swith stacks. After this, execution continues in F2's context, which can be one
    # of the following:
    #
    # - a call to run if it is a new fiber
    # - a previous call to resume. if it was suspending while resuming another
    #   thread.
    {% if flag?(:aarch64) %}
      Fiber.switch_stacks(pointerof(current.@stack_top), @stack_top)
    {% else %}
      Fiber.switch_stacks(pointerof(current.@stack_top), pointerof(@stack_top))
    {% end %}

    # To finish the process of resuming F2, we need to release the GC lock and
    # run F1's callback. This has to be done in both the end of Fiber#resume and
    # on Fiber#run.
    #
    # If execution continues here, that means F2 was suspended while giving
    # control to another fiber (F3).
    #
    # Note that stacks were changed, so any local variable doesn't necessarily
    # reference the same objects that before the switch. At this point we have:
    #   - current: F2
    #   - self:  F3

    Fiber.gc_read_unlock

    # Call F1's resume callback, which we had previously stored in F2's instance
    # variable.
    current.flush_callback
  end

  property callback

  protected def flush_callback
    if callback = @callback
      callback.call
      @callback = nil
    end
  end

  protected def transfer_callback
    @callback.tap do
      @callback = nil
    end
  end

  def sleep(time)
    event = @resume_event ||= EventLoop.create_resume_event(self)
    @callback = ->{
      event.add(time)
      nil
    }
    EventLoop.wait
  end

  def yield
    @callback = ->{
      Scheduler.current.enqueue self
      nil
    }
    Scheduler.current.reschedule
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

  def self.current=(fiber)
    Thread.current.current_fiber = fiber
  end

  @@prev_push_other_roots : ->
  @@prev_push_other_roots = LibGC.get_push_other_roots

  LibGC.set_start_callback ->do
    Fiber.gc_write_lock
  end

  # This will push all fibers stacks whenever the GC wants to collect some memory
  LibGC.set_push_other_roots ->do
    fiber = @@first_fiber
    while fiber
      if thread = fiber.@thread
        LibGC.set_stackbottom thread, fiber.@stack_bottom
      else
        fiber.push_gc_roots
      end

      fiber = fiber.next_fiber
    end

    @@prev_push_other_roots.call
    Fiber.gc_write_unlock
  end
end
