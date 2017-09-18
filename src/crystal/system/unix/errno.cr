{% skip_file() unless flag?(:unix) %}

require "c/errno"
require "c/string"

lib LibC
  {% if flag?(:linux) %}
    {% if flag?(:musl) %}
      fun __errno_location : Int*
    {% else %}
      @[ThreadLocal]
      $errno : Int
    {% end %}
  {% elsif flag?(:darwin) || flag?(:freebsd) %}
    fun __error : Int*
  {% elsif flag?(:openbsd) %}
    fun __error = __errno : Int*
  {% end %}
end

module Crystal::System::Errno
  # Returns the value of libc's errno.
  def self.value : LibC::Int
    {% if flag?(:linux) %}
      {% if flag?(:musl) %}
        LibC.__errno_location.value
      {% else %}
        LibC.errno
      {% end %}
    {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      LibC.__error.value
    {% end %}
  end

  # Sets the value of libc's errno.
  def self.value=(value)
    {% if flag?(:linux) %}
      {% if flag?(:musl) %}
        LibC.__errno_location.value = value
      {% else %}
        LibC.errno = value
      {% end %}
    {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      LibC.__error.value = value
    {% end %}
  end
end
