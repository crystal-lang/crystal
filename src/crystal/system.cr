module Crystal
  # :nodoc
  module System
    # Returns the hostname
    # def self.hostname

    # Returns the number of logical processors available to the system.
    #
    # def self.cpu_count

    # Returns the short user name of the currently logged in user.
    #
    # def self.login
  end
end

require "./system/unix/hostname"
require "./system/unix/login"

{% if flag?(:freebsd) || flag?(:openbsd) %}
  require "./system/unix/sysctl_cpucount"
{% else %}
  # TODO: restrict on flag?(:unix) after crystal > 0.22.0 is released
  require "./system/unix/sysconf_cpucount"
{% end %}
