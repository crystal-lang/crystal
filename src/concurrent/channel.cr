require "fiber"

abstract class Channel(T)
  @mutex = Thread::Mutex.new

  module SelectAction
    # Executes the action if the channel is ready
    # Returns a tuple { is_ready, result } (where result is nil if the result is not ready)
    abstract def try_execute
    abstract def wait
    abstract def unwait
  end

  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  def initialize
    @closed = false
    @senders = Deque(Fiber).new
    @receivers = Deque(Fiber).new
  end

  def self.new : Unbuffered(T)
    Unbuffered(T).new
  end

  def self.new(capacity) : Buffered(T)
    Buffered(T).new(capacity)
  end

  def close
    @mutex.synchronize do
      @closed = true
      Scheduler.current.enqueue @receivers
      @receivers.clear
      nil
    end
  end

  def closed?
    @closed
  end

  # Perform the receive operation, assuming the access is synchronized (see Channel#synchronize)
  abstract def receive_immediate

  def receive
    receive_impl { raise ClosedError.new }
  end

  def receive?
    receive_impl { return nil }
  end

  # Perform the send operation, assuming the access is synchronized (see Channel#synchronize)
  abstract def send_immediate(value : T)

  abstract def send(value : T)

  def inspect(io)
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end

  def wait_for_receive
    @mutex.synchronize do
      @receivers << Fiber.current
    end
  end

  def unwait_for_receive
    @mutex.synchronize do
      @receivers.delete Fiber.current
    end
  end

  def wait_for_send
    @mutex.synchronize do
      @senders << Fiber.current
    end
  end

  def unwait_for_send
    @mutex.synchronize do
      @senders.delete Fiber.current
    end
  end

  def synchronize
    @mutex.synchronize do
      yield
    end
  end

  protected def unlock_after_context_switch
    Fiber.current.callback = ->{
      @mutex.unlock
      nil
    }
  end

  protected def raise_if_closed
    if @closed
      @mutex.unlock
      raise ClosedError.new
    end
  end

  def self.receive_first(*channels)
    receive_first channels
  end

  def self.receive_first(channels : Tuple | Array)
    self.select(channels.map(&.receive_select_action))[1]
  end

  def self.send_first(value, *channels)
    send_first value, channels
  end

  def self.send_first(value, channels : Tuple | Array)
    self.select(channels.map(&.send_select_action(value)))
    nil
  end

  def self.select(*ops : SelectAction)
    self.select ops
  end

  def self.select(ops : Tuple | Array, has_else = false)
    loop do
      ops.each_with_index do |op, index|
        ready, result = op.try_execute
        if ready
          return index, result
        end
      end

      if has_else
        return ops.size, nil
      end

      ops.each &.wait
      Scheduler.current.reschedule
      ops.each &.unwait
    end
  end

  def send_select_action(value : T)
    SendAction.new(self, value)
  end

  def receive_select_action
    ReceiveAction.new(self)
  end

  struct ReceiveAction(C)
    include SelectAction

    def initialize(@channel : C)
    end

    def try_execute
      @channel.synchronize do
        if !@channel.empty?
          return true, @channel.receive_immediate
        else
          return false, nil
        end
      end
    end

    def wait
      @channel.wait_for_receive
    end

    def unwait
      @channel.unwait_for_receive
    end
  end

  struct SendAction(C, T)
    include SelectAction

    def initialize(@channel : C, @value : T)
    end

    def try_execute
      @channel.synchronize do
        if !@channel.full?
          return true, @channel.send_immediate(@value)
        else
          return false, nil
        end
      end
    end

    def wait
      @channel.wait_for_send
    end

    def unwait
      @channel.unwait_for_send
    end
  end
end

class Channel::Buffered(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Deque(T).new(@capacity)
    super()
  end

  def send_immediate(value : T)
    raise_if_closed

    @queue << value
    unless @receivers.empty?
      Scheduler.current.enqueue @receivers
      @receivers.clear
    end

    self
  end

  def send(value : T)
    @mutex.lock

    while full?
      raise_if_closed
      thread_log "#{Fiber.current.name!} waiting to send in channel #{self}"
      @senders << Fiber.current
      unlock_after_context_switch
      Scheduler.current.reschedule
      @mutex.lock
    end

    begin
      send_immediate(value)
    ensure
      @mutex.unlock
    end
  end

  def receive_immediate
    result = @queue.shift.tap do
      unless @senders.empty?
        Scheduler.current.enqueue @senders
        @senders.clear
      end
    end

    result
  end

  private def receive_impl
    @mutex.lock

    while empty?
      if @closed
        @mutex.unlock
        yield
      end
      thread_log "#{Fiber.current.name!} waiting to receive in channel #{self}"
      @receivers << Fiber.current

      unlock_after_context_switch
      Scheduler.current.reschedule
      @mutex.lock
    end

    begin
      receive_immediate
    ensure
      @mutex.unlock
    end
  end

  def full?
    @queue.size >= @capacity
  end

  def empty?
    @queue.empty?
  end
end

class Channel::Unbuffered(T) < Channel(T)
  @sender : Fiber?

  def initialize
    @has_value = false
    @value = uninitialized T
    super
  end

  def send_immediate(value : T)
    send_internal(value)
    @mutex.lock
  end

  def send(value : T)
    @mutex.lock

    while @has_value
      raise_if_closed
      thread_log "#{Fiber.current.name!} waiting to send in channel #{self}"
      @senders << Fiber.current
      unlock_after_context_switch
      Scheduler.current.reschedule
      @mutex.lock
    end

    send_internal(value)
  end

  # Performs the send operations. Handles the lock to the receiving fiber.
  private def send_internal(value : T)
    raise_if_closed

    @value = value
    @has_value = true
    @sender = Fiber.current

    receiver = @receivers.shift?
    unlock_after_context_switch

    thread_log "#{Fiber.current.name!} waiting for value to be read in channel #{self}"
    if receiver
      receiver.resume
    else
      Scheduler.current.reschedule
    end
  end

  def receive_immediate
    if @closed
      raise ClosedError.new
    end

    @value.tap do
      @has_value = false
      Scheduler.current.enqueue @sender.not_nil!
    end
  end

  private def receive_impl
    @mutex.lock

    until @has_value
      if @closed
        @mutex.unlock
        yield
      end

      thread_log "#{Fiber.current.name!} waiting to receive in channel #{self}"
      @receivers << Fiber.current
      sender = @senders.shift?

      unlock_after_context_switch

      if sender
        sender.resume
      else
        Scheduler.current.reschedule
      end

      @mutex.lock
    end

    if @closed
      @mutex.unlock
      yield
    end

    @value.tap do
      @has_value = false
      Scheduler.current.enqueue @sender.not_nil!
      @mutex.unlock
    end
  end

  def empty?
    !@has_value
  end

  def full?
    @has_value || @receivers.empty?
  end
end
