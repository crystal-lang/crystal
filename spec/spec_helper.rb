require 'bundler/setup'
require 'pry'
require 'pry-debugger'

if ENV["CI"]
  require 'simplecov'
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter 'lib/crystal/profiler.rb'
    add_filter 'lib/crystal/graph.rb'
    add_filter 'lib/crystal/print_types_visitor.rb'
  end
end

require(File.expand_path("../../lib/crystal",  __FILE__))

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run_excluding :integration, :primitives
end

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f }
