require "../process"

# :nodoc:
struct CallStack
  struct Addr2line
    @@has_command : Bool?
    @@command_path : String?

    def self.command_path?
      {% if flag?(:darwin) || flag?(:freebsd) || flag?(:linux) %}
        if @@has_command.nil?
          {% if flag?(:darwin) %}
            name = "atos"
          {% else %}
            name = "addr2line"
          {% end %}

          process = Process.new("command -v #{name}", shell: true, output: nil)

          begin
            if output = process.output.gets
              @@command_path = output.strip
              @@has_command = true
            else
              @@has_command = false
            end
          ensure
            process.close
          end
        end
        @@command_path
      {% end %}
    end

    def self.open
      addr2line = new
      begin
        yield addr2line
      ensure
        addr2line.close
      end
    end

    @process : Process?

    def initialize
      if cmd = Addr2line.command_path?
        {% if flag?(:darwin) %}
          @process = Process.new(cmd, {"-o", PROGRAM_NAME}, input: nil, output: nil)
        {% else %}
          @process = Process.new(cmd, {"-e", PROGRAM_NAME}, input: nil, output: nil)
        {% end %}
      end
    end

    def finalize
      close
    end

    def close
      @process.try(&.close)
    end

    def decode(ip)
      if process = @process
        process.input << ip.address.to_s(16) << '\n'
        if output = process.output.gets
          if pos = output.index(':')
            file = output[0, pos]
            line = output[pos + 1...-1]
            return {file, line}
          else
            {output, "?"}
          end
        end
      end
      {"??", "?"}
    end
  end
end
