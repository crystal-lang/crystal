lib LibC
  {% if flag?(:darwin) || flag?(:freebsd) %}
    fun sysctlbyname(LibC::Char*, Void*, LibC::SizeT*, Void*, LibC::SizeT) : Int32
  {% end %}
end

# Provides access to UNIX kernels state using the `sysctl` system call
module Sysctl
  extend self

  # Returns the sysctl named *name* as an integer. Will raise `NotImplemented`
  # if the sysctl interface doesn't exist on your system (Windows) or isn't
  # supported yet. Will raise the appropriate `Errno` exception in case of
  # error.
  #
  # ```
  # Sysctl.get_int("hw.ncpu") # => 8
  # ```
  #
  def i32(name : String) : Int32
    {% if flag?(:darwin) || flag?(:freebsd) %}
      value = GC.malloc_atomic(sizeof(Int32)).as(Int32*)
      value_len = GC.malloc_atomic(sizeof(Int32)).as(Int32*)
      value_len.value = sizeof(Int32)

      res = LibC.sysctlbyname(name.to_unsafe, value.as(Void*),
        value_len.as(LibC::SizeT*), Pointer(Void).null, 0)

      if res == 0
        value.value
      else
        raise Errno.new("Unable to fetch sysctl value #{name}")
      end
    {% elsif flag?(:linux) %}
      path = name_to_path name
      read_proc_sys(path).to_i32
    {% else %}
      raise NotImplemented.new("Sysctl", "is not supported on this platform")
    {% end %}
  end

  # Returns a sysctl value named *name* as a `String`. Will raise
  # `NotImplemented` on systems where the sysctl interface doesn't exists or
  # isn't supported. Will also raise the appropriate `Errno` in case of error.
  #
  # ```
  # Sysctl.get_str("kernel.random.boot_id", 42) # => "1c629298-a60b-48df-bba1-9ea77f6b37ba"
  # ```
  #
  def str(name : String, max_size : Int32) : String
    {% if flag?(:darwin) || flag?(:freebsd) %}
      value = GC.malloc_atomic(max_size).as(LibC::Char*)
      value_len = GC.malloc_atomic(sizeof(Int32)).as(Int32*)
      value_len.value = max_size

      res = LibC.sysctlbyname(name.to_unsafe, value.as(Void*),
        value_len.as(LibC::SizeT*), Pointer(Void).null, 0)

      if res == 0
        String.new(value, value_len.value - 1, 1)
      else
        raise Errno.new("Unable to fetch sysctl value #{name}")
      end
    {% elsif flag?(:linux) %}
      path = name_to_path name
      read_proc_sys(path)
    {% else %}
      raise NotImplemented.new("Sysctl", "is not supported on this platform")
    {% end %}
  end

  {% if flag?(:linux) %}
    # :nodoc:
    def name_to_path(name : String)
      "/proc/sys/" + name.gsub(".", "/")
    end

    # :nodoc:
    def read_proc_sys(path : String) : String
      if File.readable?(path)
        File.read(path)
      else
        raise Errno.new("Unable to read #{path}", Errno::ENOENT)
      end
    end
  {% end %}
end
