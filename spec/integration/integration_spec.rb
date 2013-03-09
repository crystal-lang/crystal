require 'spec_helper'

describe "integration" do
  COMPILER = File.expand_path("../../../bin/crystal",  __FILE__)
  SPECS = File.expand_path("../../../spec/crystal/crystal_spec.cr",  __FILE__)

  Dir[File.expand_path("../pending/**/*.cr",  __FILE__)].each do |file|
    pending "compiles #{File.basename file}", integration: true do
    end
  end

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

  # it "passes all crystal specs", integration: true do
  #   output = %x(#{SPECS})
  #   unless output =~ /0 failures/
  #     fail output
  #   end
  # end
end
