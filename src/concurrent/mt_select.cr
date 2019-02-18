abstract class Channel(T)
  module SelectAction
    abstract def ready?
    abstract def execute
    abstract def wait
    abstract def unwait
  end

  def self.select(*ops : SelectAction)
    self.select(ops)
  end

  def self.select(ops : Tuple | Array, has_else = false)
    raise "Not Implemented Error: select isn't implemented for MT"

    # ops.each_with_index do |op, index|
    #   if op.ready?
    #     result = op.execute
    #     return index, result
    #   end
    # end

    # if has_else
    #   return ops.size, nil
    # end

    # mutex = Crystal::Mutex.new
    # condition_variable = Crystal::ConditionVariable.new
    # selected = -1

    # mutex.lock

    # ops.each_with_index do |op, index|
    #   spawn do
    #     loop do
    #       break if op.canceled?

    #       if op.ready?
    #         mutex.lock
    #         selected = index
    #         condition_variable.signal
    #         mutex.unlock
    #         break if op.canceled?
    #       end

    #       op.wait
    #     end
    #   end
    # end

    # loop do
    #   condition_variable.wait(pointerof(mutex))
    #   value, success = op.execute
    #   if success
    #     ops.each(&.cancel)
    #     mutex.unlock
    #     return value
    #   end
    # end
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
      @channel.receive_nonblock
    end

    def wait
      @channel.wait_for_receive
    end

    def unwait
      @channel.unwait_for_receive
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
      @channel.send_nonblock(@value)
    end

    def wait
      @channel.wait_for_send
    end

    def unwait
      @channel.unwait_for_send
    end
  end
end
