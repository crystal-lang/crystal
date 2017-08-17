module Crystal
  # :nodoc:
  module System
    # :nodoc:
    module Process
      # Returns possible location of executable path
      # def self.executable_path_impl
    end
  end
end

{% if flag?(:darwin) %}
  require "./darwin/process"
{% elsif flag?(:freebsd) %}
  require "./freebsd/process"
{% elsif flag?(:linux) %}
  require "./linux/process"
{% else %}
  module System
    # nodoc
    class Process
      INITIAL_PATH = ENV["PATH"]?
      INITIAL_PWD = Dir.current

      def self.executable_path_impl
        ::Process.find_executable(PROGRAM_NAME, INITIAL_PATH, INITIAL_PWD)
      end
    end
  end
{% end %}
