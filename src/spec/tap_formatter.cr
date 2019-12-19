# :nodoc:
class Spec::TAPFormatter < Spec::Formatter
  @counter = 0

  def report(result)
    case result.kind
    when :success
      @io << "ok"
    when :fail, :error
      @io << "not ok"
    when :pending
      @io << "ok"
    end

    @counter += 1

    @io << ' ' << @counter << " -"
    if result.kind == :pending
      @io << " # SKIP"
    end
    @io << ' ' << result.description

    @io.puts
  end

  def finish(elapsed_time, aborted)
    @io << "1.." << @counter
    @io.puts
  end
end
