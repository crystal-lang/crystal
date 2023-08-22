{% if flag?(:preview_mt) %}
  require "crystal/thread_local_value"
{% end %}

# `Reference` is the base class of classes you define in your program.
# It is set as a class' superclass when you don't specify one:
#
# ```
# class MyClass # < Reference
# end
# ```
#
# A reference type is passed by reference: when you pass it to methods,
# return it from methods or assign it to variables, a pointer is actually passed.
#
# Invoking `new` on a `Reference` allocates a new instance on the heap.
# The instance's memory is automatically freed (garbage-collected) when
# the instance is no longer referred by any other entity in the program.
class Reference
  # Returns `true` if this reference is the same as *other*. Invokes `same?`.
  def ==(other : self)
    same?(other)
  end

  # Returns `false` (other can only be a `Value` here).
  def ==(other)
    false
  end

  # Returns `true` if this reference is the same as *other*. This is only
  # `true` if this reference's `object_id` is the same as *other*'s.
  def same?(other : Reference) : Bool
    object_id == other.object_id
  end

  # Returns `false`: a reference is never `nil`.
  def same?(other : Nil)
    false
  end

  # Returns a shallow copy of this object.
  #
  # This allocates a new object and copies the contents of
  # `self` into it.
  def dup
    {% if @type.abstract? %}
      # This shouldn't happen, as the type is abstract,
      # but we need to avoid the allocate invocation below
      raise "Can't dup {{@type}}"
    {% else %}
      dup = self.class.allocate
      dup.as(Void*).copy_from(self.as(Void*), instance_sizeof(self))
      GC.add_finalizer(dup) if dup.responds_to?(:finalize)
      dup
    {% end %}
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.reference(self)
  end

  # Appends a String representation of this object
  # which includes its class name, its object address
  # and the values of all instance variables.
  #
  # ```
  # class Person
  #   def initialize(@name : String, @age : Int32)
  #   end
  # end
  #
  # Person.new("John", 32).inspect # => #<Person:0x10fd31f20 @name="John", @age=32>
  # ```
  def inspect(io : IO) : Nil
    io << "#<" << {{@type.name.id.stringify}} << ":0x"
    object_id.to_s(io, 16)

    executed = exec_recursive(:inspect) do
      {% for ivar, i in @type.instance_vars %}
        {% if i > 0 %}
          io << ','
        {% end %}
        io << " @{{ivar.id}}="
        @{{ivar.id}}.inspect io
      {% end %}
    end
    unless executed
      io << " ..."
    end
    io << '>'
  end

  def pretty_print(pp) : Nil
    {% if @type.overrides?(Reference, "inspect") %}
      pp.text inspect
    {% else %}
      prefix = "#<#{{{@type.name.id.stringify}}}:0x#{object_id.to_s(16)}"
      executed = exec_recursive(:pretty_print) do
        pp.surround(prefix, ">", left_break: nil, right_break: nil) do
          {% for ivar, i in @type.instance_vars.map(&.name).sort %}
            {% if i == 0 %}
              pp.breakable
            {% else %}
              pp.comma
            {% end %}
            pp.group do
              pp.text "@{{ivar.id}}="
              pp.nest do
                pp.breakable ""
                @{{ivar.id}}.pretty_print(pp)
              end
            end
          {% end %}
        end
      end
      unless executed
        pp.text "#{prefix} ...>"
      end
    {% end %}
  end

  # Appends a short String representation of this object
  # which includes its class name and its object address.
  #
  # ```
  # class Person
  #   def initialize(@name : String, @age : Int32)
  #   end
  # end
  #
  # Person.new("John", 32).to_s # => #<Person:0x10a199f20>
  # ```
  def to_s(io : IO) : Nil
    io << "#<" << self.class.name << ":0x"
    object_id.to_s(io, 16)
    io << '>'
  end

  # :nodoc:
  module ExecRecursive
    # NOTE: can't use `Set` here because of prelude require order
    alias Registry = Hash({UInt64, Symbol}, Nil)

    {% if flag?(:preview_mt) %}
      @@exec_recursive = Crystal::ThreadLocalValue(Registry).new
    {% else %}
      @@exec_recursive = Registry.new
    {% end %}

    def self.hash
      {% if flag?(:preview_mt) %}
        @@exec_recursive.get { Registry.new }
      {% else %}
        @@exec_recursive
      {% end %}
    end
  end

  private def exec_recursive(method, &)
    hash = ExecRecursive.hash
    key = {object_id, method}
    hash.put(key, nil) do
      yield
      hash.delete(key)
      return true
    end
    false
  end

  # :nodoc:
  module ExecRecursiveClone
    alias Registry = Hash(UInt64, UInt64)

    {% if flag?(:preview_mt) %}
      @@exec_recursive = Crystal::ThreadLocalValue(Registry).new
    {% else %}
      @@exec_recursive = Registry.new
    {% end %}

    def self.hash
      {% if flag?(:preview_mt) %}
        @@exec_recursive.get { Registry.new }
      {% else %}
        @@exec_recursive
      {% end %}
    end
  end

  # Helper method to perform clone by also checking recursiveness.
  # When clone is wanted, call this method. Then create the clone
  # instance without any contents (don't fill it out yet), then
  # put the clone's object id into the hash yielded into the block.
  # At the end of the block return the cloned object.
  #
  # For example:
  #
  # ```
  # def clone
  #   exec_recursive_clone do |hash|
  #     clone = SomeClass.new
  #     hash[object_id] = clone.object_id
  #     # fill out the clone object
  #     clone
  #   end
  # end
  # ```
  private def exec_recursive_clone(&)
    hash = ExecRecursiveClone.hash
    clone_object_id = hash[object_id]?
    unless clone_object_id
      clone_object_id = yield(hash).object_id
      hash.delete(object_id)
    end
    Pointer(Void).new(clone_object_id).as(self)
  end
end
