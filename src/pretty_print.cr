# This class implements a pretty printing algorithm.
# It finds line breaks and nice indentations for grouped structure.
#
# ### References
#
# * [Ruby's prettyprint.rb](https://github.com/ruby/ruby/blob/trunk/lib/prettyprint.rb)
# * [Christian Lindig, Strictly Pretty, March 2000](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.34.2200)
# * [Philip Wadler, A prettier printer, March 1998](http://homepages.inf.ed.ac.uk/wadler/topics/language-design.html#prettier)
class PrettyPrint
  protected getter group_queue
  protected getter newline
  protected getter indent

  # Creates a new pretty printer that will write to the given *output*
  # and be capped at *maxwidth*.
  def initialize(@output : IO, @maxwidth = 79, @newline = "\n", @indent = 0)
    @output_width = 0
    @buffer_width = 0

    # Buffer of object that can't yet be printed to
    # the output because we don't know if the current
    # group overflows maxwidth or not
    @buffer = Deque(Text | Breakable).new

    root_group = Group.new(0)

    # All groups being pushed by `group` calls
    @group_stack = [] of Group
    @group_stack << root_group

    # Queue of array of groups (one array per group level)
    # that are not yet breakable
    @group_queue = GroupQueue.new
    @group_queue.enq root_group
  end

  protected def current_group
    @group_stack.last
  end

  # Checks if the current output width plus the
  # total width accumulated in buffer objects exceeds
  # the maximum allowed width. If so, it means that
  # all groups until the first break must be broken
  # into newlines, and all breakables and texts until
  # that point can be printed.
  protected def break_outmost_groups
    while @maxwidth < @output_width + @buffer_width
      return unless group = @group_queue.deq

      until group.breakables.empty?
        data = @buffer.shift
        @output_width = data.output(@output, @output_width)
        @buffer_width -= data.width
      end

      while !@buffer.empty? && @buffer.first.is_a?(Text)
        text = @buffer.shift.as(Text)
        @output_width = text.output(@output, @output_width)
        @buffer_width -= text.width
      end
    end
  end

  # Appends a text element.
  def text(obj)
    obj = obj.to_s
    width = obj.size
    return if width == 0

    if @buffer.empty?
      @output << obj
      @output_width += width
    else
      text = @buffer.last
      unless text.is_a?(Text)
        text = Text.new
        @buffer << text
      end
      text.add(obj, width)
      @buffer_width += width
      break_outmost_groups
    end
  end

  # Appends an element that can turn into a newline if necessary.
  def breakable(sep = " ")
    width = sep.size
    group = @group_stack.last
    if group.break?
      flush
      @output << @newline
      @indent.times { @output << " " }
      @output_width = @indent
      @buffer_width = 0
    else
      @buffer << Breakable.new(sep, width, self)
      @buffer_width += width
      break_outmost_groups
    end
  end

  # Similar to `#breakable` except
  # the decision to break or not is determined individually.
  def fill_breakable(sep = " ")
    group { breakable sep }
  end

  # Creates a group of objects. Inside a group all breakable
  # objects are either turned into newlines or are output
  # as is, depending on the available width.
  def group(indent = 0, open_obj = "", close_obj = "")
    text open_obj
    group_sub do
      nest(indent) do
        yield
      end
    end
    text close_obj
  end

  private def group_sub
    group = Group.new(@group_stack.last.depth + 1)
    @group_stack.push group
    @group_queue.enq group
    begin
      yield
    ensure
      @group_stack.pop
      if group.breakables.empty?
        @group_queue.delete group
      end
    end
  end

  # Increases the indentation for breakables inside the current group.
  def nest(indent = 1)
    @indent += indent
    begin
      yield
    ensure
      @indent -= indent
    end
  end

  # Same as:
  #
  # ```
  # text ","
  # breakable
  # ```
  def comma
    text ","
    breakable
  end

  # Appends a group that is surrounded by the given *left* and *right*
  # objects, and optionally is surrounded by the given breakable
  # objects.
  def surround(left, right, left_break = "", right_break = "") : Nil
    group(1, left, right) do
      breakable left_break if left_break
      yield
      breakable right_break if right_break
    end
  end

  # Appends a list of elements surrounded by *left* and *right*
  # and separated by commas, yielding each element to the given block.
  def list(left, elements, right) : Nil
    group(1, left, right) do
      elements.each_with_index do |elem, i|
        comma if i > 0
        yield elem
      end
    end
  end

  # Appends a list of elements surrounded by *left* and *right*
  # and separated by commas.
  def list(left, elements, right) : Nil
    list(left, elements, right) do |elem|
      elem.pretty_print(self)
    end
  end

  # Outputs any buffered data.
  def flush
    @buffer.each do |data|
      @output_width = data.output(@output, @output_width)
    end
    @buffer.clear
    @buffer_width = 0
  end

  private class Text
    getter width

    def initialize
      @objs = [] of String
      @width = 0
    end

    def output(out, output_width)
      @objs.each { |obj| out << obj }
      output_width + @width
    end

    def add(obj, width)
      @objs << obj.to_s
      @width += width
    end
  end

  private class Breakable
    @indent : Int32
    @group : Group
    getter width

    def initialize(@obj : String, @width : Int32, @pp : PrettyPrint)
      @indent = @pp.indent
      @group = @pp.current_group
      @group.breakables.push self
    end

    def output(out, output_width)
      @group.breakables.shift
      if @group.break?
        out << @pp.newline
        @indent.times { out << " " }
        @indent
      else
        @pp.group_queue.delete @group if @group.breakables.empty?
        out << @obj
        output_width + @width
      end
    end
  end

  private class Group
    getter depth
    getter breakables
    getter? :break

    def initialize(@depth : Int32)
      @breakables = Deque(Breakable).new
      @break = false
    end

    def break
      @break = true
    end
  end

  private class GroupQueue
    def initialize
      @queue = [] of Array(Group)
    end

    def enq(group)
      depth = group.depth
      until depth < @queue.size
        @queue << [] of Group
      end
      @queue[depth] << group
    end

    def deq
      @queue.each do |gs|
        (gs.size - 1).downto(0) do |i|
          unless gs[i].breakables.empty?
            group = gs.delete_at(i)
            group.break
            return group
          end
        end
        gs.each &.break
        gs.clear
      end
      nil
    end

    def delete(group)
      @queue[group.depth].delete(group)
    end
  end

  # Pretty prints *obj* into *io* with the given
  # *width* as a limit and starting with
  # the given *indent*ation.
  def self.format(obj, io : IO, width : Int32, newline = "\n", indent = 0)
    format(io, width, newline, indent) do |printer|
      obj.pretty_print(printer)
    end
  end

  # Creates a pretty printer and yields it to the block,
  # appending any output to the given *io*.
  def self.format(io : IO, width : Int32, newline = "\n", indent = 0)
    printer = PrettyPrint.new(io, width, newline, indent)
    yield printer
    printer.flush
    io
  end
end
