require "fiber_safe_mutex"

# The Singleton module implements the Singleton pattern.
#
### Usage
#
# ```
# require "singleton"
#
# class Foo
#   include Singleton
# end
#
# foo = Foo.instance
# ```
module Singleton
  macro included
    @@mutex = FiberSafeMutex.new

    # Instantiate the object if it doesn't exist.  Always returns the same object.
    def self.instance
      @@instance ||= @@mutex.synchronize do
        @@instance ||= new
      end
    end

    # Return the already instantiated object.  Returns nil otherwise.
    def self.instance?
      @@instance
    end
  end

  def dup
    raise "can't dup a Singleton"
  end

  def clone
    raise "can't clone a Singleton"
  end
end
