# :nodoc:
module Crystal::System
  # Returns the hostname
  # def self.hostname

  # Returns the number of logical processors available to the system.
  #
  # def self.cpu_count
end

{% if flag?(:wasi) %}
  require "./system/wasi/hostname"
  require "./system/wasi/cpucount"
{% elsif flag?(:unix) %}
  require "./system/unix/hostname"

  {% if flag?(:bsd) %}
    require "./system/unix/sysctl_cpucount"
  {% else %}
    require "./system/unix/sysconf_cpucount"
  {% end %}
{% elsif flag?(:win32) %}
  require "./system/win32/hostname"
  require "./system/win32/cpucount"
{% else %}
  {% raise "No Crystal::System implementation available" %}
{% end %}
