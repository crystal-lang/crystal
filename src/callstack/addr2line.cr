require "../process"

# :nodoc:
struct CallStack
  skip(__FILE__)

  # :nodoc:
  module Addr2line
    @@has_command : Bool?
    @@command : String?

    def self.command?
      {% if flag?(:darwin) %}
        name = "atos"
      {% elsif flag?(:linux) || flag?(:freebsd) %}
        name = "addr2line"
      {% else %}
        nil
      {% end %}
    end

    def self.decode(addresses)
      symbols = Array(Tuple(String, String)).new(addresses.size)

      if command = command?
        args = Array(String).new(addresses.size + 2)

        {% if flag?(:darwin) %}
          args << "-o"
        {% else %}
          args << "-e"
        {% end %}

        args << PROGRAM_NAME

        addresses.each do |ip|
          args << ip.address.to_s(16)
        end

        Process.run(command, args, output: nil) do |process|
          while output = process.output.gets
            if pos = output.index(':')
              file = output[0, pos]
              line = output[pos + 1...-1]
              symbols << {file, line}
              next
            else
              symbols << {output, "?"}
              next
            end
            symbols << {"??", "?"}
          end
        end
      end

      symbols
    end
  end
end
