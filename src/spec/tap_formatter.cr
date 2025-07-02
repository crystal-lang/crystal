# :nodoc:
class Spec::TAPFormatter < Spec::Formatter
  @counter = 0

  def report(result)
    io = @cli.stdout

    case result.kind
    in .success?
      io << "ok"
    in .fail?, .error?
      io << "not ok"
    in .pending?
      io << "ok"
    end

    @counter += 1

    io << ' ' << @counter << " -"
    if result.kind.pending?
      io << " # SKIP"
    end
    io << ' ' << result.description

    io.puts
  end

  def finish(elapsed_time, aborted)
    @cli.stdout << "1.." << @counter
    @cli.stdout.puts
  end
end
