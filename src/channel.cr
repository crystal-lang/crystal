require "fiber"

abstract class Channel(T)
  module SelectAction
    getter? canceled = false
    getter? waiting = false

    abstract def ready?
    abstract def execute
    abstract def wait : Bool
    abstract def unwait(fiber : Fiber)
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
    Crystal::Scheduler.enqueue @senders
    @senders.clear
    Crystal::Scheduler.enqueue @receivers
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

  protected def wait_for_receive
    @receivers << Fiber.current
  end

  protected def unwait_for_receive(fiber)
    @receivers.delete fiber
  end

  protected def wait_for_send
    @senders << Fiber.current
  end

  protected def unwait_for_send(fiber)
    @senders.delete fiber
  end

  protected def raise_if_closed
    raise ClosedError.new if @closed
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

  # :nodoc:
  def self.select(*ops : SelectAction)
    self.select ops
  end

  # :nodoc:
  #
  # Executes all operations inside its own fiber to wait in. Postpones the fiber
  # execution so the fibers' array will always be filled with all fibers, and
  # any ready operation can cancel all other fibers ASAP.
  def self.select(ops : Tuple | Array, has_else = false)
    # fast path: check if any clause is ready
    ops.each_with_index do |op, i|
      if op.ready?
        return {i, op.execute}
      end
    end

    if has_else
      return {ops.size, nil}
    end

    # slow path: spawn fibers to wait on each clause
    main = Fiber.current
    fibers = Array(Fiber).new(ops.size)
    index = -1
    value = nil

    ops.each_with_index do |op, i|
      fibers << Fiber.new(name: i.to_s) do
        loop do
          break if op.canceled?

          if op.ready?
            # cancel other fibers before executing the op, which could switch
            # the current context:
            cancel_select_actions(ops, fibers, i)
            index, value = i, op.execute
            Crystal::Scheduler.enqueue(main)
            break
          end

          op.wait
          Crystal::Scheduler.reschedule
        end
      end
    end

    Crystal::Scheduler.enqueue(fibers)
    Crystal::Scheduler.reschedule

    {index, value}
  end

  private def self.cancel_select_actions(ops, fibers, running_index)
    ops.each_with_index do |op, i|
      next if i == running_index
      fiber = fibers[i]
      op.unwait(fiber)
      Crystal::Scheduler.enqueue(fiber) if op.waiting?
    end
  end

  # :nodoc:
  def send_select_action(value : T)
    SendAction.new(self, value)
  end

  # :nodoc:
  def receive_select_action
    ReceiveAction.new(self)
  end

  # :nodoc:
  class ReceiveAction(C)
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
      @waiting = true
    end

    def unwait(fiber)
      @canceled = true
      @channel.unwait_for_receive(fiber)
    end
  end

  # :nodoc:
  class SendAction(C, T)
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
      @waiting = true
    end

    def unwait(fiber)
      @canceled = true
      @channel.unwait_for_send(fiber)
    end
  end
end

class Channel::Buffered(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Deque(T).new(@capacity)
    super()
  end

  def send(value : T)
    while full?
      raise_if_closed
      @senders << Fiber.current
      Crystal::Scheduler.reschedule
    end

    raise_if_closed

    @queue << value
    Crystal::Scheduler.enqueue @receivers
    @receivers.clear

    self
  end

  private def receive_impl
    while empty?
      yield if @closed
      @receivers << Fiber.current
      Crystal::Scheduler.reschedule
    end

    @queue.shift.tap do
      Crystal::Scheduler.enqueue @senders
      @senders.clear
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

  def send(value : T)
    while @has_value
      raise_if_closed
      @senders << Fiber.current
      Crystal::Scheduler.reschedule
    end

    raise_if_closed

    @value = value
    @has_value = true
    @sender = Fiber.current

    if receiver = @receivers.shift?
      receiver.resume
    else
      Crystal::Scheduler.reschedule
    end
  end

  private def receive_impl
    until @has_value
      yield if @closed
      @receivers << Fiber.current
      if sender = @senders.shift?
        sender.resume
      else
        Crystal::Scheduler.reschedule
      end
    end

    yield if @closed

    @value.tap do
      @has_value = false
      Crystal::Scheduler.enqueue @sender.not_nil!
      @sender = nil
    end
  end

  def empty?
    !@has_value && @senders.empty?
  end

  def full?
    @has_value || @receivers.empty?
  end

  def close
    super
    if sender = @sender
      Crystal::Scheduler.enqueue sender
      @sender = nil
    end
  end
end
