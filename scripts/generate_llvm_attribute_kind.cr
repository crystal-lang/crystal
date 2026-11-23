#! /usr/bin/env crystal
#
# Generates the LLVM version-specific definitions of `LLVM::AttributeKind`, by
# running `llvm-tblgen` with the original `Attributes.td` file from LLVM's
# include directory. Succeeds if no changes are produced in
# `src/llvm/enums/attribute_kind/llvm_*.cr`.

require "llvm"
require "json"

llvm_config = ENV["LLVM_CONFIG"]? || Process.capture("sh", "#{__DIR__}/../src/llvm/ext/find-llvm-config.sh")
bindir = Process.capture(llvm_config, "--bindir").chomp
includedir = Process.capture(llvm_config, "--includedir").chomp
llvm_tblgen = File.join(bindir, "llvm-tblgen")

attributes_td = "#{includedir}/llvm/IR/Attributes.td"
attributes_json = JSON.parse(Process.capture(llvm_tblgen, "--dump-json", attributes_td, "-I", includedir))

instanceof = attributes_json["!instanceof"]
attr_names = instanceof["Attr"].as_a
instanceof["StrBoolAttr"]?.try { |v| attr_names -= v.as_a }
instanceof["ComplexStrAttr"]?.try { |v| attr_names -= v.as_a }

kind_ids = attr_names.map do |attr_name|
  attr_name = attr_name.as_s
  attr = attributes_json[attr_name]
  attr_string = attr["AttrString"].as_s
  attr_type = attr["!superclasses"][-1].as_s
  kind_id = LLVM::AttributeKind.id_from_name(attr_string)
  {attr_name, kind_id, attr_type}
end

llvm_version = Process.capture(llvm_config, "--version")
llvm_version_major, _, _ = llvm_version.partition(".")
puts "LLVM version detected: #{llvm_version}"

f = IO::Memory.new
f.puts <<-CRYSTAL
  {% skip_file unless LibLLVM::VERSION_MAJOR == #{llvm_version_major} %}

  # WARNING: This enum is marked as unstable by LLVM. The following members are
  # valid for LLVM #{llvm_version_major}. Refer to `src/llvm/enums/attribute_kind/llvm_*.cr` to see
  # if a particular member was added or removed.
  enum LLVM::AttributeKind : UInt32
  CRYSTAL

kind_ids.sort_by! &.[1]
kind_ids.each do |attr, kind_id, attr_type|
  f.puts "  #{attr} = #{kind_id} # #{attr_type}"
end

f.puts "end"

f.rewind
cr = Process.capture("crystal", "tool", "format", "-", input: f)

fname = "#{__DIR__}/../src/llvm/enums/attribute_kind/llvm_#{llvm_version_major}.cr"
old = File.read(fname) rescue nil
unless cr == old
  File.write(fname, cr)
  puts "#{File.expand_path(fname)} has been modified!"
  puts cr
  exit 1
end
