# :nodoc:
class Crystal::ValueWithFinalizer(T)
  getter value : T

  def initialize(@value : T, @finalizer : T ->)
  end

  def finalize
    @finalizer.call(@value)
  end
end
