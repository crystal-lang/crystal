# This file defines the `__crystal_once` functions expected by the compiler. It
# is called each time a constant or class variable has to be initialized and is
# its responsibility to verify the initializer is executed only once and to fail
# on recursion.
#
# It also defines the `__crystal_once_init` function for backward compatibility
# with older compiler releases. It is executed only once at the beginning of the
# program and, for the legacy implementation, the result is passed on each call
# to `__crystal_once`.

require "crystal/pointer_linked_list"
require "crystal/spin_lock"

module Crystal
  # :nodoc:
  module Once
    enum State : Int8
      Processing    = -1
      Uninitialized =  0
      Initialized   =  1
    end

    {% if compare_versions(Crystal::VERSION, "1.16.0-dev") >= 0 %}
      alias FlagT = State
    {% else %}
      alias FlagT = Bool
    {% end %}

    struct Operation
      include PointerLinkedList::Node

      getter fiber : Fiber
      getter flag : FlagT*

      def initialize(@flag : FlagT*, @fiber : Fiber)
        @waiting = PointerLinkedList(Fiber::PointerLinkedListNode).new
      end

      def add_waiter(node) : Nil
        @waiting.push(node)
      end

      def resume_all : Nil
        @waiting.each(&.value.enqueue)
      end
    end

    @@spin = uninitialized SpinLock
    @@operations = uninitialized PointerLinkedList(Operation)

    def self.init : Nil
      @@spin = SpinLock.new
      @@operations = PointerLinkedList(Operation).new
    end

    protected def self.exec(flag : FlagT*, &)
      @@spin.lock

      exec_impl(flag) { yield }

      # safety check, and allows to safely call `Intrinsics.unreachable` in
      # `__crystal_once`
      if flag.is_a?(State*)
        return if flag.value.initialized?
      else
        return if flag.value
      end

      System.print_error "BUG: failed to initialize constant or class variable\n"
      LibC._exit(1)
    end

    private def self.run_initializer(flag, &)
      if flag.is_a?(State*)
        flag.value = State::Processing
      end
      operation = Operation.new(flag, Fiber.current)
      @@operations.push pointerof(operation)
      @@spin.unlock

      yield

      @@spin.lock
      if flag.is_a?(State*)
        flag.value = State::Initialized
      else
        flag.value = true
      end
      @@operations.delete pointerof(operation)
      @@spin.unlock

      operation.resume_all
    end

    # Searches if a fiber is already running the initializer, in which case it
    # checks for reentrancy then suspends the fiber until the value is ready and
    # returns true; otherwise immediately returns false.
    private def self.wait_initializer?(flag) : Bool
      @@operations.each do |operation|
        next unless operation.value.flag == flag

        current_fiber = Fiber.current

        if operation.value.fiber == current_fiber
          @@spin.unlock
          raise "Recursion while initializing class variables and/or constants"
        end

        waiting = Fiber::PointerLinkedListNode.new(current_fiber)
        operation.value.add_waiter(pointerof(waiting))
        @@spin.unlock

        Fiber.suspend
        return true
      end

      false
    end
  end

  # :nodoc:
  @[NoInline]
  def self.once(flag : Once::FlagT*, initializer : Void*)
    Once.exec(flag, &Proc(Nil).new(initializer, Pointer(Void).null))
  end
end

{% if compare_versions(Crystal::VERSION, "1.16.0-dev") >= 0 %}
  module Crystal
    module Once
      private def self.exec_impl(flag, &)
        case flag.value
        in .initialized?
          @@spin.unlock
          return
        in .uninitialized?
          run_initializer(flag) { yield }
        in .processing?
          raise "unreachable" unless wait_initializer?(flag)
        end
      end
    end

    # :nodoc:
    def self.once(flag : Once::State*, &)
      Once.exec(flag) { yield } unless flag.value.initialized?
    end
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_once(flag : Crystal::Once::State*, initializer : Void*)
    return if flag.value.initialized?
    Crystal.once(flag, initializer)
    Intrinsics.unreachable unless flag.value.initialized?
  end
{% else %}
  module Crystal
    module Once
      private def self.exec_impl(flag, &)
        if flag.value
          @@spin.unlock
        elsif !wait_initializer?(flag)
          run_initializer(flag) { yield }
        end
      end
    end

    # :nodoc:
    def self.once(flag : Bool*, &)
      Once.exec(flag) { yield } unless flag.value
    end
  end

  # :nodoc:
  fun __crystal_once_init : Void*
    Pointer(Void).null
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
    return if flag.value
    Crystal.once(flag, initializer)
    Intrinsics.unreachable unless flag.value
  end
{% end %}
