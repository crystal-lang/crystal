require "fiber"

abstract class Channel(T)
  @mutex = Thread::Mutex.new

  module SelectAction
    # Executes the action if the channel is ready
    # Returns a tuple { is_ready, result } (where result is nil if the result is not ready)
    abstract def execute_or_wait(ticket : FiberTicket)
    abstract def unwait(ticket : FiberTicket)
  end

  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  def initialize
    @closed = false
    @senders = Deque(FiberTicket).new
    @receivers = Deque(FiberTicket).new
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
      fibers = @receivers.reduce([] of Fiber) do |acc, ticket|
        if fiber = ticket.checkout!
          acc << fiber
        else
          acc
        end
      end
      Scheduler.enqueue fibers
      @receivers.clear
      nil
    end
  end

  def closed?
    @closed
  end

  def empty?
    synchronize { internal_empty? }
  end

  def full?
    synchronize { internal_full? }
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

  # holds lock
  protected def wait_for_receive(ticket)
    @receivers << ticket
  end

  def unwait_for_receive(ticket)
    @mutex.synchronize do
      @receivers.delete ticket
    end
  end

  # holds lock
  def wait_for_send(ticket)
    @senders << ticket
  end

  def unwait_for_send(ticket)
    @mutex.synchronize do
      @senders.delete ticket
    end
  end

  def synchronize
    @mutex.synchronize do
      yield
    end
  end

  protected def unlock_after_context_switch
    Fiber.current.append_callback ->{
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
      thread_log "Trying to execute select operations"
      ticket = FiberTicket.for_current
      ticket.lock
      begin
        ops.each_with_index do |op, index|
          ready, result = op.execute_or_wait(ticket)
          if ready
            return index, result
          end
        end

        # TODO: we can optimize this case by not creating a ticket in the first
        # place since we are never going to block on the channels
        if has_else
          return ops.size, nil
        end

        thread_log "Waiting for operations"
        Fiber.current.append_callback ->{
          ticket.unlock
          nil
        }
        Scheduler.current.reschedule
        thread_log "Done waiting"
      ensure
        ticket.clear_and_unlock!
        # TODO: this may not be necessary... we can let the channels clean up
        # since the ticket is invalidated anyway
        ops.each_with_index do |op, index|
          op.unwait ticket
        end
      end
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

    def execute_or_wait(ticket)
      @channel.synchronize do
        if !@channel.internal_empty?
          return true, @channel.receive_immediate
        else
          @channel.wait_for_receive ticket
          return false, nil
        end
      end
    end

    def unwait(ticket)
      @channel.unwait_for_receive(ticket)
    end
  end

  struct SendAction(C, T)
    include SelectAction

    def initialize(@channel : C, @value : T)
    end

    def execute_or_wait(ticket)
      @channel.synchronize do
        if !@channel.internal_full?
          return true, @channel.send_immediate(@value)
        else
          @channel.wait_for_send ticket
          return false, nil
        end
      end
    end

    def unwait(ticket)
      @channel.unwait_for_send(ticket)
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
      fibers = @receivers.reduce([] of Fiber) do |acc, ticket|
        if fiber = ticket.checkout!
          acc << fiber
        else
          acc
        end
      end
      Scheduler.enqueue fibers
      @receivers.clear
    end

    self
  end

  def send(value : T)
    @mutex.lock

    while internal_full?
      raise_if_closed
      # thread_log "#{Fiber.current.name!} waiting to send in channel #{self}"
      @senders << FiberTicket.for_current
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
        fibers = @senders.reduce([] of Fiber) do |acc, ticket|
          if fiber = ticket.checkout!
            acc << fiber
          else
            acc
          end
        end
        Scheduler.enqueue fibers
        @senders.clear
      end
    end

    result
  end

  private def receive_impl
    @mutex.lock

    while internal_empty?
      if @closed
        @mutex.unlock
        yield
      end
      # thread_log "#{Fiber.current.name!} waiting to receive in channel #{self}"
      @receivers << FiberTicket.for_current

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

  # holds lock
  protected def internal_full?
    @queue.size >= @capacity
  end

  # holds lock
  protected def internal_empty?
    @queue.empty?
  end
end

class Channel::Unbuffered(T) < Channel(T)
  @current_sender : Fiber?

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
      # thread_log "#{Fiber.current.name!} waiting to send in channel #{self}"
      @senders << FiberTicket.for_current
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
    @current_sender = Fiber.current

    while !@receivers.empty?
      receiver = @receivers.shift.checkout!
      break if receiver
    end
    unlock_after_context_switch

    if receiver
      thread_log "#{Fiber.current.name!} resuming receiver #{receiver.name!} for read in channel #{self}"
      receiver.resume
    else
      thread_log "#{Fiber.current.name!} waiting for value to be read in channel #{self}"
      Scheduler.current.reschedule
    end
  end

  def receive_immediate
    if @closed
      raise ClosedError.new
    end

    @value.tap do
      @has_value = false
      Scheduler.enqueue @current_sender.not_nil!
    end
  end

  private def receive_impl
    @mutex.lock

    until @has_value
      if @closed
        @mutex.unlock
        yield
      end

      @receivers << FiberTicket.for_current
      while !@senders.empty?
        sender = @senders.shift.checkout!
        break if sender
      end
      unlock_after_context_switch

      if sender
        thread_log "#{Fiber.current.name!} resuming #{sender.name!} for receive in channel #{self}"
        sender.resume
      else
        thread_log "#{Fiber.current.name!} waiting to receive in channel #{self}"
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
      Scheduler.enqueue @current_sender.not_nil!
      @mutex.unlock
    end
  end

  # holds lock
  protected def internal_empty?
    !@has_value
  end

  # holds lock
  protected def internal_full?
    @has_value || @receivers.empty?
  end
end

# This class represents a fiber willing to send/receive on a channel.
# Can be safely enqueued into multiple channels without fear of resuming
# twice since only the first channel will be able to checkout the fiber.
class FiberTicket
  @lock = SpinLock.new
  @fiber : Fiber?

  def initialize(@fiber)
  end

  def checkout!
    @lock.synchronize do
      fiber = @fiber
      @fiber = nil
      fiber
    end
  end

  def clear_and_unlock!
    @fiber = nil
    @lock.unlock
  end

  def lock
    @lock.lock
  end

  def unlock
    @lock.unlock
  end

  def self.for_current
    new Fiber.current
  end
end
