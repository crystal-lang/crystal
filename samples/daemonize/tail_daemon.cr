require "tempfile"

stdout = Tempfile.new("out")
stdin  = Tempfile.new("in")

puts <<-THE_END
Reading from #{stdin.path}
Writing to #{stdout.path}
To kill daemon: 'echo "exit" >> #{stdin.path}'
THE_END

Process.daemonize( stdin: stdin.path, stdout: stdout.path)

def process(msg)
	if msg
	  puts "read line '#{msg.chop}'"
		if msg.chop == "exit"
			puts "bye"
			exit
		end
	end
end

loop { process(STDIN.gets) }
