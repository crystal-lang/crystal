# :nodoc:
module Crystal::System
  # Returns the hostname
  # def self.hostname

  # Returns the number of logical processors available to the system.
  #
  # def self.cpu_count
end

require "./system/unix/hostname"

{% if flag?(:freebsd) || flag?(:openbsd) %}
  require "./system/unix/sysctl_cpucount"
{% elsif flag?(:unix) %}
  require "./system/unix/sysconf_cpucount"
{% end %}
