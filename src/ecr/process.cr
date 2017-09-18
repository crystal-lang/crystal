require "ecr/processor"

filename = ARGV[0]
buffer_name = ARGV[1]

begin
  puts ECR.process_file(filename, buffer_name)
rescue ex : OSError::FileNotFound | OSError::IsADirectory
  STDERR.puts ex.message
  exit 1
end
