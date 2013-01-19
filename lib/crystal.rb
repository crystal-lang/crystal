module Crystal
  extend self

  DUMP_LLVM = ENV['DUMP'] == '1'
  UNIFY = ENV['UNIFY'] != '0'
  LOG = ENV['LOG'] == '1'
  CACHE = ENV['CACHE'] != '0'
  GENERIC = ENV['GENERIC'] != '0'
  CHECK = ENV['CHECK'] == '1'

  def check_correctness?
    @check_correctness || ENV['CHECK'] == '1'
  end

  def check_correctness!
    @check_correctness = true
  end
end

Dir["#{File.expand_path('../',  __FILE__)}/**/*.rb"].each do |filename|
  require filename
end
