PROGRAM_NAME = String.new(ARGV_UNSAFE.value)
ARGV = (ARGV_UNSAFE + 1).to_slice(ARGC_UNSAFE - 1).map { |c_str| String.new(c_str) }
