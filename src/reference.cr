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
  # Constructs an object in-place at the given *address*, forwarding *args* and
  # *opts* to `#initialize`. Returns that object.
  #
  # This method can be used to decouple object allocation from initialization.
  # For example, the instance data might come from a custom allocator, or it
  # might reside on the stack using a type like `ReferenceStorage`.
  #
  # *address* must point to a suitably aligned buffer of at least
  # `instance_sizeof(self)` bytes.
  #
  # WARNING: This method is unsafe, as it assumes the caller is responsible for
  # managing the memory at the given *address* manually.
  #
  # ```
  # class Foo
  #   getter i : Int64
  #   getter str = "abc"
  #
  #   def initialize(@i)
  #   end
  #
  #   def finalize
  #     puts "bye"
  #   end
  # end
  #
  # foo_buffer = uninitialized ReferenceStorage(Foo)
  # foo = Foo.unsafe_construct(pointerof(foo_buffer), 123_i64)
  # begin
  #   foo # => #<Foo:0x... @i=123, @str="abc">
  # ensure
  #   foo.finalize if foo.responds_to?(:finalize) # prints "bye"
  # end
  # ```
  #
  # See also: `Reference.pre_initialize`.
  @[Experimental("This API is still under development. Join the discussion about custom reference allocation at [#13481](https://github.com/crystal-lang/crystal/issues/13481).")]
  def self.unsafe_construct(address : Pointer, *args, **opts) : self
    obj = pre_initialize(address)
    obj.initialize(*args, **opts)
    obj
  end

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
      raise "Can't dup {{ @type }}"
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
    io << "#<" << {{ @type.name.id.stringify }} << ":0x"
    object_id.to_s(io, 16)

    executed = exec_recursive(:inspect) do
      {% for ivar, i in @type.instance_vars %}
        {% if i > 0 %}
          io << ','
        {% end %}
        io << " @{{ ivar.id }}="
        @{{ ivar.id }}.inspect io
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
      prefix = "#<#{{{ @type.name.id.stringify }}}:0x#{object_id.to_s(16)}"
      executed = exec_recursive(:pretty_print) do
        pp.surround(prefix, ">", left_break: nil, right_break: nil) do
          {% for ivar, i in @type.instance_vars.map(&.name).sort %}
            {% if i == 0 %}
              pp.breakable
            {% else %}
              pp.comma
            {% end %}
            pp.group do
              pp.text "@{{ ivar.id }}="
              pp.nest do
                pp.breakable ""
                @{{ ivar.id }}.pretty_print(pp)
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

  private def exec_recursive(method, &)
    # NOTE: can't use `Set` because of prelude require order
    hash = Fiber.current.exec_recursive_hash
    key = {object_id, method}
    hash.put(key, nil) do
      yield
      return true
    ensure
      hash.delete(key)
    end
    false
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
    # NOTE: can't use `Set` because of prelude require order
    hash = Fiber.current.exec_recursive_clone_hash
    clone_object_id = hash.fetch(object_id) do
      yield(hash).object_id
    ensure
      hash.delete(object_id)
    end
    Pointer(Void).new(clone_object_id).as(self)
  end
end
