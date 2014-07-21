ARGV = (ARGV_UNSAFE + 1).as_enumerable(ARGC_UNSAFE - 1).map { |c_str| String.new(c_str) }
