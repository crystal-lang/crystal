require "fiber"

class Channel(T)
  # Raised when send value to closed channel or receive value from empty closed channel
  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  # Creates a new empty Channel with `capacity`
  #
  # The `capacity` is the size of buffer. If `capacity` is zero, then the channel is unbuffered;
  # Otherwise it is buffered channel.
  #
  # ```
  # unbuffered_ch = Channel(Int32).new
  # buffered_ch = Channel(Int32).new 5
  # ```
  def initialize(@capacity = 0)
    # queue store availiable data if status > 0, otherwise it
    # store incomplete task need to be set data
    @queue = Deque(SimpleIVar(T) | SelectIVar(T)).new

    # the number of difference between send and wait, and it will not exceed @capacity
    @status = 0

    # store send to send_wait if queue is full
    @send_wait = Deque(Tuple(T, SimpleIVar(T) | SelectIVar(T))).new

    # true if channel closed
    @closed = false

    # for synchronize
    @mutex = Thread::Mutex.new

    # priority for execute select
    @priority = 0_u64

    # for priority synchronize, spin lock would be better
    @priority_lock = Thread::Mutex.new

    # the count of the thread hold priority
    @priority_ref_count = 0
  end

  # Send value into channel. It returns value which send when send is complete.
  # Raise `ClosedError` if closed.
  #
  # ```
  # channel = Channel(Int32).new 1
  # channel.send 2 # => channel
  # ```
  def send(value : T)
    send_impl(value) { raise ClosedError.new }.get
  end

  # Send value into channel. It returns value which send when send is complete.
  # Returns `nil` if closed.
  def send?(value : T)
    send_impl(value) { return nil }.get?
  end

  private def send_impl(value : T)
    @mutex.synchronize do
      yield if @closed
      loop do
        if @status >= @capacity
          ivar = SimpleIVar(T).new
          tuple = {value, ivar}
          @send_wait.push tuple
          return ivar
        elsif @status >= 0
          ivar = SimpleIVar(T).new
          ivar.value = value
          @queue.push ivar
          @status += 1
          return ivar
        else
          ivar = @queue.shift
          @status += 1

          # make sure receive ivar is incomplete
          next unless ivar.try_set_value? value
          return ivar
        end
      end
    end
  end

  protected def send?(value : T, wait_ivar) : Nil
    send_impl(value, wait_ivar) do
      wait_ivar.try_set_error? ClosedError.new
      break nil
    end
  end

  protected def send_impl(value : T, wait_ivar) : Nil
    @mutex.synchronize do
      yield if @closed
      loop do
        if @status >= @capacity
          tuple = {value, wait_ivar}
          @send_wait.push tuple
        elsif @status >= 0
          # make sure send ivar is incomplete
          if wait_ivar.try_set_value? value
            @queue.push wait_ivar
            @status += 1
          end
        else
          # make sure recieve ivar is complete
          if (ivar = @queue.first).try_complete?
            # make sure send ivar is complete
            if wait_ivar.try_set_value? value
              ivar.complete_set_value value
              @queue.shift
              @status += 1
            else
              ivar.reset
            end
          else
            @queue.shift
            @status += 1
            next
          end
        end

        break
      end
    end
  end

  # receive value from channel. It returns value when receive is complete.
  # Raise `ClosedError` if closed.
  #
  # ```
  # ch = Channel(Int32).new
  # ch.send 1
  # ch.receive # => 1
  # ```
  def receive
    receive_impl { raise ClosedError.new }.get
  end

  # Recieve value from channel. It returns value when receive is complete.
  # Returns `nil` if closed.
  def receive?
    receive_impl { return nil }.get?
  end

  protected def receive_impl
    @mutex.synchronize do
      loop do
        if tuple = @send_wait.shift?
          # make sure send ivar is incomplete
          next unless tuple[1].try_set_value? tuple[0]
          @queue.push tuple[1]
          return @queue.shift
        elsif @status > 0
          @status -= 1
          return @queue.shift
        else
          yield if @closed
          ivar = SimpleIVar(T).new
          @queue.push ivar
          @status -= 1
          return ivar
        end
      end
    end
  end

  protected def receive?(ivar)
    receive_impl(ivar) do
      ivar.try_set_error? ClosedError.new
      break nil
    end
  end

  protected def receive_impl(ivar) : Nil
    @mutex.synchronize do
      loop do
        if tuple = @send_wait.first?
          # make sure recieve ivar is incomplete
          if ivar.try_complete?
            @send_wait.shift

            # make sure send ivar is incomplete
            if tuple[1].try_set_value? tuple[0]
              @queue.push tuple[1]
              livar = @queue.shift
              ivar.complete_set_value livar.get
            else
              ivar.reset
              next
            end
          end
        elsif @status > 0
          livar = @queue.first

          # make sure recieve ivar is not completed
          if ivar.try_set_value? livar.get
            @queue.shift
            @status -= 1
          end
        else
          yield if @closed
          @queue.push ivar
          @status -= 1
        end

        break
      end
    end
  end

  def send_select_action(value : T)
    SendAction.new self, value
  end

  def receive_select_action
    ReceiveAction.new self
  end

  # Close channel. It is able to receive value if there are remaining send values.
  #
  # ```
  # ch = Channel(Int32).new
  # ch.close
  # ```
  def close : Nil
    return if @closed
    @mutex.synchronize do
      @closed = true
      if @status < 0
        @queue.each &.try_set_error? ClosedError.new
        @queue.clear
        @status = 0
      end
    end
  end

  # Returns `true` if channel closed, otherwise `false`.
  #
  # ```
  # ch = Channel(Int32).new
  # ch.closed? # => false
  # ch.close
  # ch.closed? # => true
  # ```
  def closed?
    @closed
  end

  # Returns `true` if the buffer of channel is full, otherwise `false`.
  #
  # ```
  # ch = Channel(Int32).new 1
  # ch.full? # => false
  # ch.send 1
  # ch.full? # => true
  # ```
  def full?
    @status >= @capacity
  end

  # Returns `true` if the buffer of channel is empty, otherwise `false`.
  #
  # ```
  # ch = Channel(Int32).new 1
  # ch.empty? # => true
  # ch.send 1
  # ch.empty? # => false
  # ```
  def empty?
    if @capacity > 0
      @status <= 0
    else
      @send_wait.empty?
    end
  end

  protected def acquire_priority
    @priority_lock.synchronize do
      @priority = Random.rand(UInt64::MAX) if @priority_ref_count == 0
      @priority_ref_count += 1
      return @priority
    end
  end

  protected def release_priority
    @priority_lock.synchronize do
      @priority_ref_count -= 1
    end
  end

  # Send first value into given channels.
  #
  # ```
  # ch1 = Channel(Int32).new 1
  # ch2 = Channel(Int32).new 1
  # ch1.send 1
  # Channel.send_first(2, ch1, ch2)
  # ch2.receive # => 2
  # ```
  def self.send_first(value : T, *channels : Channel(T)) forall T
    wait_ivar = SimpleIVar(T).new
    channels.each &.send?(value, wait_ivar)
    wait_ivar.get
    nil
  end

  # Send first value into given channels.
  def self.send_first(value : T, channels : Array(Channel(T))) forall T
    wait_ivar = SimpleIVar(T).new
    channels.each &.send?(value, wait_ivar)
    wait_ivar.get
    nil
  end

  # Receive first value from given channels.
  #
  # ```
  # ch1 = Channel(Int32).new 1
  # ch2 = Channel(Int32).new 1
  # ch1.send 1
  # Channel.receive_first(ch1, ch2) # => 1
  # ```
  def self.receive_first(*channels : Channel(T)) forall T
    ivar = SimpleIVar(T).new
    channels.each &.receive?(ivar)
    ivar.get
  end

  # Receive first value from given channels.
  def self.receive_first(channels : Array(Channel(T))) forall T
    ivar = SimpleIVar(T).new
    channels.each &.receive?(ivar)
    ivar.get
  end

  # Select one of action to execute.
  #
  # ```
  # ch1 = Channel(Int32).new 1
  # ch2 = Channel(Int32).new 1
  # ch1.send 123
  # status = 0
  # Channel.select do |x|
  #   x.receive_action ch1 do |val|
  #     val # => 123
  #     status = 1
  #   end
  #
  #   x.receive_action ch2 do |val|
  #     status = 2
  #   end
  # end
  # status # => 1
  # ```
  def self.select
    yield selector = Selector.new
    selector.run
  end

  def self.select(ops : Tuple, has_else = false)
    self.select *ops, has_else: has_else
  end

  def self.select(*ops : *T, has_else = false) forall T
    idx, ret = -1, nil
    self.select do |x|
      {% for i in 0...T.size %}
        ops[{{i}}].execute x do |val|
          idx, ret = {{i}}, val
        end
      {% end %}

      if has_else
        x.default_action do
          idx, ret = ops.size, nil
        end
      end
    end
    return idx, ret
  end

  def self.select(ops : Array, has_else = false)
    idx, ret = -1, nil
    self.select do |x|
      ops.each_with_index do |op, index|
        op.execute x do |val|
          idx, ret = index, val
        end
      end

      if has_else
        x.default_action do
          idx, ret = ops.size, nil
        end
      end
    end
    return idx, ret
  end

  private class Selector
    @ivar = SimpleIVar(->).new
    @actions = [] of Tuple({UInt64, UInt64}, Proc(Nil))
    @cleanups = [] of Proc(Nil)

    def send_action(ch : Channel(T), value : T, &block : T ->) forall T
      tuple = Tuple.new Tuple.new(ch.acquire_priority, ch.object_id), ->do
        svar = SelectIVar(T).new @ivar, &block
        ch.send?(value, svar)
        nil
      end

      @actions << tuple
      @cleanups << ->do
        ch.release_priority
        nil
      end
    end

    def receive_action(ch : Channel(T), &block : T ->) forall T
      tuple = Tuple.new Tuple.new(ch.acquire_priority, ch.object_id), ->do
        svar = SelectIVar(T).new @ivar, &block
        ch.receive?(svar)
        nil
      end

      @actions << tuple
      @cleanups << ->do
        ch.release_priority
        nil
      end
    end

    def default_action(&@default : ->)
    end

    protected def run
      @actions.group_by { |id, proc| id }
              .map { |id, arr| arr[Random.rand(arr.size)] }
              .sort_by! { |id, proc| id }
              .each { |id, proc| proc.call }
      @cleanups.each &.call

      @default.try { |x| @ivar.try_set_value? x }
      @ivar.get.call
    end
  end

  module SelectAction(T)
    abstract def execute(selector, &block : T ->)
  end

  struct SendAction(T)
    include SelectAction(T)

    def initialize(@ch : Channel(T), @value : T)
    end

    def execute(selector, &block : T ->)
      selector.send_action @ch, @value, &block
    end
  end

  struct ReceiveAction(T)
    include SelectAction(T)

    def initialize(@ch : Channel(T))
    end

    def execute(selector, &block : T ->)
      selector.receive_action @ch, &block
    end
  end
end

private module Status
  INCOMPLETE  = 0
  MAYCOMPLETE = 1
  COMPLETED   = 2
  FAULTED     = 3
end

private class SimpleIVar(T)
  @value : T?
  @error : Exception?
  @status = Atomic(Int32).new Status::INCOMPLETE
  @cur_fiber : Fiber?

  def get
    get_impl { raise @error.not_nil! }
  end

  def get?
    get_impl { break nil }
  end

  private def get_impl
    wait
    case @status.get
    when Status::COMPLETED
      return @value.as(T)
    when Status::FAULTED
      yield
    else
      raise "compiler bug"
    end
  end

  def value=(value : T) : Nil
    unless try_set_value? value
      raise "Invalid Operation!"
    end
  end

  def try_set_value?(value : T)
    if try_complete?
      complete_set_value value
      true
    else
      false
    end
  end

  def error=(error : Exception) : Nil
    unless try_set_error? error
      raise "Invalid Operation!"
    end
  end

  def try_set_error?(error : Exception)
    if try_complete?
      complete_set_error error
      true
    else
      false
    end
  end

  def try_complete?
    loop do
      if (tuple = @status.compare_and_set(Status::INCOMPLETE, Status::MAYCOMPLETE))[1]
        return true
      elsif tuple[0] != Status::MAYCOMPLETE
        return false
      end
    end
  end

  def reset : Nil
    unless @status.compare_and_set(Status::MAYCOMPLETE, Status::INCOMPLETE)[1]
      raise "Invalid Status!"
    end
  end

  def complete_set_value(value : T) : Nil
    @value = value
    @cur_fiber.try { |x| Scheduler.enqueue x }
    unless @status.compare_and_set(Status::MAYCOMPLETE, Status::COMPLETED)[1]
      raise "Invalid Status!"
    end
  end

  def complete_set_error(error : Exception) : Nil
    @error = error
    @cur_fiber.try { |x| Scheduler.enqueue x }
    unless @status.compare_and_set(Status::MAYCOMPLETE, Status::FAULTED)[1]
      raise "Invalid Status!"
    end
  end

  def wait
    wait_impl do
      if try_complete?
        @cur_fiber = Fiber.current
        reset
        Scheduler.reschedule
      end
    end
  end

  def wait_impl
    while @status.get < Status::COMPLETED
      yield
    end
  end
end

private class SelectIVar(T)
  @value : T?
  @error : Exception?
  @status = Atomic(Int32).new Status::INCOMPLETE
  @proc : ->
  @cur_fiber : Fiber?

  def initialize(@ivar : SimpleIVar(->), &block : T ->)
    @proc = ->{ block.call(get) }
  end

  def get
    get_impl { raise @error.not_nil! }
  end

  def get?
    get_impl { break nil }
  end

  private def get_impl
    wait
    case @status.get
    when Status::COMPLETED
      return @value.as(T)
    when Status::FAULTED
      yield
    else
      raise "compiler bug"
    end
  end

  def value=(value : T) : Nil
    unless try_set_value? value
      raise "Invalid Operation!"
    end
  end

  def try_set_value?(value : T)
    if @ivar.try_set_value? @proc
      @value = value
      @cur_fiber.try { |x| Scheduler.enqueue x }
      @status.lazy_set(Status::COMPLETED)
      true
    else
      false
    end
  end

  def error=(error : Exception) : Nil
    unless try_set_error? error
      raise "Invalid Operation!"
    end
  end

  def try_set_error?(error : Exception)
    if @ivar.try_set_value? @proc
      @error = error
      @cur_fiber.try { |x| Scheduler.enqueue x }
      @status.lazy_set(Status::FAULTED)
      true
    else
      false
    end
  end

  delegate try_complete?, reset, to: @ivar

  def complete_set_value(value : T) : Nil
    @ivar.complete_set_value @proc
    @value = value
    @cur_fiber.try { |x| Scheduler.enqueue x }
    @status.lazy_set(Status::COMPLETED)
  end

  def complete_set_error(error : Exception) : Nil
    @ivar.complete_set_value @proc
    @error = error
    @cur_fiber.try { |x| Scheduler.enqueue x }
    @status.lazy_set(Status::FAULTED)
  end

  def wait
    wait_impl do
      if try_complete?
        @cur_fiber = Fiber.current
        reset
        Scheduler.reschedule
      end
    end
  end

  def wait_impl
    while @status.get < Status::COMPLETED
      yield
    end
  end
end
