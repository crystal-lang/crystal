require "logger"
require "tempfile"
puts "Daemonizing..."

stdout = Tempfile.new("out")
stderr = Tempfile.new("err")
stdin = Tempfile.new("in")

puts <<-THE_END
STDOUT is #{stdout.path}
STDERR is #{stderr.path}
STDIN  is #{stdin.path}
THE_END

Process.daemonize(stdout: stdout.path, stderr: stderr.path, stdin: stdin.path)

begin
  log = Logger.new(STDERR)
  log.level = Logger::WARN

  loop do
    sleep 1
    puts "I am writing to STDOUT"
    log.warn("I am writing to STDERR")
  end
ensure
  stdout.delete
  stderr.delete
  stdin.delete
end
