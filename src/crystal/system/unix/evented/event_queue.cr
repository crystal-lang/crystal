require "./event"

# NOTE: this is a struct because it only wraps a const pointer to a hash
# allocated in the heap
struct Crystal::Evented::EventQueue
  class Node
    @[Flags]
    enum Registrations
      NONE  = 0
      READ  = 1
      WRITE = 2
    end

    property fd : Int32
    property registrations : Registrations
    getter readers = PointerLinkedList(Event).new
    getter writers = PointerLinkedList(Event).new

    def initialize(@fd : Int32)
      @registrations = Registrations::NONE
    end

    def empty? : Bool
      @readers.empty? && @writers.empty?
    end

    def readers? : Bool
      !@readers.empty?
    end

    def writers? : Bool
      !@writers.empty?
    end

    def add(event : Event*) : Nil
      case event.value.type
      when .io_write?
        @writers.push(event)
      else
        @readers.push(event)
      end
    end

    def each(&block : Event* ->) : Nil
      @readers.each(&block)
      @writers.each(&block)
    end

    def dequeue_reader? : Event* | Nil
      @readers.shift?
    end

    def dequeue_writer? : Event* | Nil
      @writers.shift?
    end

    def delete(event)
      case event.value.type
      when .io_write?
        @writers.delete(event)
      else
        @readers.delete(event)
      end
    end

    def clear : Nil
      @readers.clear
      @writers.clear
      @registrations = Registrations::NONE
    end
  end

  def initialize
    # OPTIMIZE: there may be a more efficient data structure than open
    # addressing hash (?)
    @list = {} of Int32 => Node
  end

  def [](fd : Int32) : Node
    @list.fetch(fd) { raise "BUG: unregistered file descriptor: #{fd}" }
  end

  def []?(fd : Int32) : Node?
    @list[fd]?
  end

  def enqueue(event : Event*) : Node
    node = @list[event.value.fd] ||= Node.new(event.value.fd)
    node.add(event)
    node
  end

  def dequeue(event : Event*) : Node
    node = self[event.value.fd]
    node.delete(event)
    node
  end

  def delete(node : Node) : Nil
    @list.delete(node.fd)
  end

  def empty? : Bool
    @list.empty?
  end

  def each(& : Node ->) : Nil
    @list.each_value { |node| yield node }
  end
end
