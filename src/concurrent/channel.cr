require "fiber"

abstract class Channel(T)
  @mutex = Thread::Mutex.new

  module SelectAction
    abstract def ready?
    abstract def execute
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
    @closed = true
    Scheduler.current.enqueue @receivers
    @receivers.clear
    nil
  end

  def closed?
    @closed
  end

  def receive
    receive_impl { raise ClosedError.new }
  end

  def receive?
    receive_impl { return nil }
  end

  def inspect(io)
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end

  def wait_for_receive
    @receivers << Fiber.current
  end

  def unwait_for_receive
    @receivers.delete Fiber.current
  end

  def wait_for_send
    @senders << Fiber.current
  end

  def unwait_for_send
    @senders.delete Fiber.current
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
        if op.ready?
          result = op.execute
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

    def ready?
      !@channel.empty?
    end

    def execute
      @channel.receive
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

    def ready?
      !@channel.full?
    end

    def execute
      @channel.send(@value)
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

  def send(value : T)
    @mutex.lock

    while full?
      raise_if_closed
      @senders << Fiber.current
      unlock_after_context_switch
      Scheduler.current.reschedule
      @mutex.lock
    end

    raise_if_closed

    @queue << value
    unless @receivers.empty?
      Scheduler.current.enqueue @receivers
      @receivers.clear
    end

    @mutex.unlock

    self
  end

  private def receive_impl
    @mutex.lock

    while empty?
      if @closed
        @mutex.unlock
        yield
      end
      @receivers << Fiber.current

      unlock_after_context_switch
      Scheduler.current.reschedule
      @mutex.lock
    end

    result = @queue.shift.tap do
      unless @senders.empty?
        Scheduler.current.enqueue @senders
        @senders.clear
      end
    end

    @mutex.unlock

    result
  end

  # holds mutex
  private def full?
    @queue.size >= @capacity
  end

  # holds mutex
  private def empty?
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

  def send(value : T)
    @mutex.lock

    while @has_value
      raise_if_closed
      @senders << Fiber.current
      unlock_after_context_switch
      Scheduler.current.reschedule
      @mutex.lock
    end

    raise_if_closed

    @value = value
    @has_value = true
    @sender = Fiber.current

    receiver = @receivers.shift?
    unlock_after_context_switch

    if receiver
      receiver.resume
    else
      Scheduler.current.reschedule
    end
  end

  private def receive_impl
    @mutex.lock

    until @has_value
      if @closed
        @mutex.unlock
        yield
      end

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
