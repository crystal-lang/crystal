require "c/unistd"
{% if flag?(:freebsd) || flag?(:openbsd) %}
  require "c/sysctl"
{% end %}

module System
  # Returns the hostname.
  #
  # NOTE: Maximum of 253 characters are allowed, with 2 bytes reserved for storage.
  # In practice, many platforms will disallow anything longer than 63 characters.
  #
  # ```
  # System.hostname # => "host.example.org"
  # ```
  def self.hostname
    String.new(255) do |buffer|
      unless LibC.gethostname(buffer, LibC::SizeT.new(255)) == 0
        raise Errno.new("Could not get hostname")
      end
      len = LibC.strlen(buffer)
      {len, len}
    end
  end

  # Returns the number of logical processors available to the system.
  #
  # ```
  # System.cpu_count # => 4
  # ```
  {% if flag?(:freebsd) || flag?(:openbsd) %}
    def self.cpu_count
      mib = Int32[LibC::CTL_HW, LibC::HW_NCPU]
      ncpus = 0
      size = sizeof(Int32).to_u64

      if LibC.sysctl(mib, 2, pointerof(ncpus), pointerof(size), nil, 0) == 0
        ncpus
      else
        -1
      end
    end
  {% else %} # linux, etc
    def self.cpu_count
      LibC.sysconf(LibC::SC_NPROCESSORS_ONLN)
    end
  {% end %}
end
