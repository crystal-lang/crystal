puts "crystal=#{Process.find_executable("crystal")}"
puts "CRYSTAL_EXEC_PATH=#{ENV["CRYSTAL_EXEC_PATH"]?}"
puts "PROGRAM_NAME=#{PROGRAM_NAME}"
puts "ARGV=#{ARGV}"
