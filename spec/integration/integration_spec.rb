require 'spec_helper'

describe "integration" do
  COMPILER = File.expand_path("../../../bin/crystal",  __FILE__)

  Dir[File.expand_path("../test_cases/**/*.cr",  __FILE__)].each do |file|
    it "compiles #{File.basename file}", integration: true do
      first_line = File.open(file, &:readline)
      output = %x(#{COMPILER} #{file} -run)
      if $?.success?
        if first_line =~ /#\s*output\s*:(.+)/ 
          output.strip.should eq($1.strip)
        end
      else
        fail output
      end
    end
  end
end
