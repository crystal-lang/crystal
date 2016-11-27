module Select
  # A select target will produce a select action when select is called.
  #
  # :nodoc:
  module Action
    abstract def execute

    abstract def activate
    abstract def deactivate
    abstract def owns_token?(resume_token : Void*)

    # Subcategory of select actions which can be checked for readiness using a
    # method call.
    module Checkable
      include Action

      abstract def ready?
    end

    # Subcategory of select actions which can be polled using the `poll`
    # syscall.
    module Pollable
      include Action

      abstract def pollfd : LibC::Pollfd
    end
  end

  def self.select(*actions : Action)
    self.select(actions)
  end

  def self.select(actions : Tuple | Array, has_else = false)
    pollfds = Array(LibC::Pollfd).new
    fdmap = Hash(Int32, Int32).new # Map of poll file descriptor to action index

    # Check checkable actions, and populate pollfds
    actions.each_with_index do |action, index|
      if action.is_a?(Action::Checkable)
        if action.ready?
          result = action.execute
          return index, result
        end
      elsif action.is_a?(Action::Pollable)
        pollfd = action.pollfd
        fdmap[pollfd.fd] = index
        pollfds << pollfd
      elsif has_else
        raise "Cannot use else clause in select with non-checkable non-pollable actions"
      end
    end

    # Call poll() on pollable actions, and return first selected fd
    retval = LibC.poll(pollfds, pollfds.size, 0)
    raise Errno.new("poll") if retval == -1
    if retval > 0
      pollfds.each do |pollfd|
        if pollfd.revents.n_val?
          raise "Bug in select: pollfd contained a closed file descriptor"
        elsif should_select? pollfd
          index = fdmap[pollfd.fd]
          result = actions[index].execute
          return index, result
        end
      end
    end

    # No actions are ready now, run else clause
    return {actions.size, nil} if has_else

    # Ask each action to resume the fiber when it's ready to be run. The
    # resuming fiber will set a resume token that the `Action` can easily
    # identify before resuming.
    actions.each &.activate
    Scheduler.reschedule
    resume_token = Fiber.current.resume_token
    actions.each &.deactivate

    action_index = actions.index &.owns_token?(resume_token)
    raise "Bug in select: no action owned the resume token" unless action_index

    result = actions[action_index].execute
    {action_index, result}
  end

  private def self.should_select?(pollfd : LibC::Pollfd)
    (pollfd.events.in? && pollfd.revents.in?) ||
      (pollfd.events.out? && pollfd.revents.out?) ||
      (pollfd.events.pri? && pollfd.revents.pri?) ||
      pollfd.revents.err? || pollfd.revents.hup?
  end
end

lib LibC
  fun poll(fds : Pollfd*, nfds : UInt64, timeout : Int32) : Int32

  struct Pollfd
    fd : Int32
    events : PollEvent
    revents : PollEvent
  end

  @[Flags]
  enum PollEvent : Int16
    In  = 0x001
    Pri = 0x002
    Out = 0x004

    Err  = 0x008
    Hup  = 0x010
    NVal = 0x020
  end
end
