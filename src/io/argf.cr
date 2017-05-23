# :nodoc:
class IO::ARGF
  include IO

  @path : String?
  @current_io : IO?

  def initialize(@argv : Array(String), @stdin : IO)
    @path = nil
    @current_io = nil
    @initialized = false
    @read_from_stdin = false
  end

  def read(slice : Bytes)
    count = slice.size
    first_initialize unless @initialized

    if current_io = @current_io
      read_count = read_from_current_io(current_io, slice, count)
    elsif !@read_from_stdin && !@argv.empty?
      # If there's no current_io it means we read all of ARGV.
      # It might be the case that the user put more strings into
      # ARGV, so in this case we need to read from that.
      read_next_argv
      read_count = read slice[0, count]
    else
      read_count = 0
    end

    read_count
  end

  # :nodoc:
  def peek
    first_initialize unless @initialized

    if current_io = @current_io
      peek = current_io.peek
      if peek && peek.empty? # EOF
        peek_next
      else
        peek
      end
    else
      peek_next
    end
  end

  private def peek_next
    if !@read_from_stdin && !@argv.empty?
      read_next_argv
      self.peek
    else
      nil
    end
  end

  def write(slice : Bytes)
    raise IO::Error.new "Can't write to ARGF"
  end

  def path
    @path || @argv.first? || "-"
  end

  private def first_initialize
    # This is the moment where we decide
    # whether we are going to use STDIN or ARGV
    @initialized = true
    if @argv.empty?
      @read_from_stdin = true
      @current_io = @stdin
    else
      read_next_argv
    end
  end

  private def read_from_current_io(current_io, slice, count)
    read_count = current_io.read slice[0, count]
    if read_count < count
      unless @read_from_stdin
        current_io.close
        if @argv.empty?
          @current_io = nil
        else
          read_next_argv
          slice += read_count
          count -= read_count
          read_count += read slice[0, count]
        end
      end
    end
    read_count
  end

  private def read_next_argv
    path = @path = @argv.shift
    @current_io = File.open(path)
  end
end
