require "ecr/processor"

filename = ARGV[0]
buffer_name = ARGV[1]

begin
  puts ECR.process_file(filename, buffer_name)
rescue ex : Errno
  if {Errno::ENOENT, Errno::EISDIR}.includes?(ex.errno)
    STDERR.puts ex.message
    exit 1
  else
    raise ex
  end
end
