module Crystal
  DUMP_LLVM = ENV['DUMP'] == '1'
  CACHE = ENV['CACHE'] != '0'
  UNIFY = ENV['UNIFY'] != '0'
end

Dir["#{File.expand_path('../',  __FILE__)}/**/*.rb"].each do |filename|
  require filename
end
