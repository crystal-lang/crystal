require "spec"
require "digest/sha1"
require "digest/md5"

private DATA          = "a" * 1024
private TOTAL_SIZE_GB = 1
private TOTAL_SIZE    = TOTAL_SIZE_GB * 1024 * 1024 * 1024

describe Digest::SHA1 do
  it "does digest for large file" do
    Digest::SHA1.digest do |ctx|
      (TOTAL_SIZE / DATA.size).ceil.to_i.times do
        ctx.update DATA
      end
    end
  end
end

describe Digest::MD5 do
  it "does digest for large file" do
    Digest::MD5.digest do |ctx|
      (TOTAL_SIZE / DATA.size).ceil.to_i.times do
        ctx.update DATA
      end
    end
  end
end
