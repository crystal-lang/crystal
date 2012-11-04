task :console do
  require 'irb'
  require 'bundler/setup'
  require 'pry'
  require 'pry-debugger'
  require 'llvm/core'
  require_relative 'lib/crystal'
  include Crystal

  if ARGV[1]
    @nodes = parse File.read(File.expand_path("../#{ARGV[1]}", __FILE__))
    @mod = infer_type @nodes

    def nodes; @nodes; end
    def mod; @mod; end
  end

  ARGV.clear
  IRB.start
end