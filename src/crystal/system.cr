# :nodoc:
module Crystal::System
  # Returns the hostname
  # def self.hostname

  # Returns the number of logical processors available to the system. Returns -1
  # on errors or when unknown.
  # def self.cpu_count

  # Returns the number of logical processors available to the process. Should be
  # less than or equal to `.cpu_count`. Returns -1 on errors or when unknown.
  def self.effective_cpu_count
    -1
  end
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
    {% if flag?(:linux) %}
      require "./system/unix/linux_cpucount"
    {% end %}
  {% end %}
{% elsif flag?(:win32) %}
  require "./system/win32/hostname"
  require "./system/win32/cpucount"
{% else %}
  {% raise "No Crystal::System implementation available" %}
{% end %}
