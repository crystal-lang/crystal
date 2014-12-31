# Reference is the base class of classes you define in your program.
# It is set as a class' superclass when you don't specify one:
#
#     class MyClass # < Reference
#     end
#
# A reference type is passed by reference: when you pass it to methods,
# return it from methods or assign it to variables, a pointer is actually passed.
#
# Invoking `new` on a Reference allocates a new instance on the heap.
# The instance's memory is automatically freed (garbage-collected) when
# the instance is no longer referred by any other entity in the program.
class Reference
  # Returns true if this reference is the same as other. Invokes #same?
  def ==(other : self)
    same?(other)
  end

  # Returns false (other can only be a Value here).
  def ==(other)
    false
  end

  # Returns true if this reference is the same as other. This is only
  # true if this reference's #obejct_id is the same as other's.
  def same?(other : Reference)
    object_id == other.object_id
  end

  # Returns false: a reference is never nil.
  def same?(other : Nil)
    false
  end

  # Returns false: a reference is never nil.
  def nil?
    false
  end

  # Returns false: a reference is always truthy.
  def !
    false
  end

  # Returns this reference's #object_id as the hash value.
  def hash
    object_id
  end

  # Returns self. Subclasses must override this method to provide
  # custom clone behaviour.
  def clone
    self
  end

  macro def inspect(io : IO) : Nil
    io << "#<{{@class_name.id}}:0x"
    object_id.to_s(16, io)

    executed = exec_recursive(:inspect) do
      {% for ivar, i in @instance_vars %}
        {% if i > 0 %}
          io << ","
        {% end %}
        io << " @{{ivar.id}}="
        @{{ivar.id}}.inspect io
      {% end %}
    end
    unless executed
      io << " ..."
    end
    io << ">"
    nil
  end

  macro def to_s(io : IO) : Nil
    io << "#<{{@class_name.id}}:0x"
    object_id.to_s(16, io)
    io << ">"
    nil
  end

  private def exec_recursive(method)
    # hash = (@[ThreadLocal] $_exec_recursive ||= {} of Tuple(UInt64, Symbol) => Bool)
    hash = ($_exec_recursive ||= {} of Tuple(UInt64, Symbol) => Bool)
    key = {object_id, method}
    if hash[key]?
      false
    else
      hash[key] = true
      value = yield
      hash.delete(key)
      true
    end
  end
end
