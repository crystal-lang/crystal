# Downloads many executable and object files from the test suites of external
# DWARF libraries, then goes to open every file supported by the current
# architecture (endianness, CPU bit size) and try to scan through the
# .debug_abbrev, .debug_info and .debug_line sections that contain the
# information to decode backtraces (function names and file, line and column).
#
# We do not assert the validity of the yielded information. There are too many
# files to write actual expectations, and comparing with the results from
# dwarfdump or another tool, while very interesting, would require quite a lot
# of work, especially since we're only interested in a subset of the
# information that the tool would return.
#
# We still verify that we can properly open the ELF, Mach-O or PE files, and
# that we can scan the DWARF sections without failing. We verify, for instance,
# that we support all the documented DW_FORM_* attributes, can read or skip over
# the attributes, without crashing (unknown FORM), or that we can properly run
# the line program's state machine.
#
# While running the spec is quite fast, this downloads several megabytes worth
# of data that we don't want to commit into the Crystal repository, nor want to
# download on everytime. Hence, the manual spec.
#
# TODO: Determine the low and high PC and verify that the addresses are within
# the range.

require "spec"
require "crystal/dwarf"

module Crystal::DWARF
  def self.parse_debug_sections(path)
    debug_line_str_name = ".debug_line_str"
    debug_str_name = ".debug_str"
    debug_line_name = ".debug_line"
    debug_abbrev_name = ".debug_abbrev"
    debug_info_name = ".debug_info"
    program = nil

    {% if flag?(:darwin) %}
      debug_line_str_name = "__debug_line_str"
      debug_str_name = "__debug_str"
      debug_line_name = "__debug_line"
      debug_abbrev_name = "__debug_abbrev"
      debug_info_name = "__debug_info"
      program = Crystal::System::MachO.open(path)
    {% elsif flag?(:unix) %}
      program = Crystal::System::ELF.open(path)
    {% elsif flag?(:win32) %}
      program = Crystal::System::PE.open(path)
    {% end %}

    unless program
      pending! "Invalid file format for the native target"
    end

    debug_abbrev = program.section?(debug_abbrev_name) { |bytes, _| bytes }
    debug_info = program.section?(debug_info_name) { |bytes, _| bytes }
    debug_line = program.section?(debug_line_name) { |bytes, _| bytes }
    debug_str = program.section?(debug_str_name) { |bytes, _| bytes }
    debug_line_str = program.section?(debug_line_str_name) { |bytes, _| bytes }

    assert_debug_str = ->(form : UInt32, value : DWARF::Info::Value) {
      case form
      when DWARF::DW_FORM_string
        value.as(Bytes)
      when DWARF::DW_FORM_strp
        offset = value.as(UInt8 | UInt16 | UInt32 | UInt64)
        offset.should be < debug_str.size if debug_str
      when DWARF::DW_FORM_line_strp
        offset = value.as(UInt8 | UInt16 | UInt32 | UInt64)
        offset.should be < debug_line_str.size if debug_line_str
      else
        # skip
      end
    }

    if debug_abbrev && debug_info
      abbrev_indexes = Hash(UInt64, Array(Int32)).new

      # index abbrev offsets to speed up scanning .debug_info attributes
      Crystal::DWARF.each_info(debug_info) do |info|
        abbrev_table = debug_abbrev + info.debug_abbrev_offset

        abbrev_indexes[info.debug_abbrev_offset] ||= Array(Int32).new.tap do |index|
          Crystal::DWARF.each_abbrev(abbrev_table) do |abbrev, offset|
            index << offset
            abbrev.each_attribute { }
          end
        end
      end

      # test: skip over attributes (no unknown DW_FORM_*)
      DWARF.each_info(debug_info) do |info|
        abbrev_table = debug_abbrev + info.debug_abbrev_offset
        abbrev_index = abbrev_indexes[info.debug_abbrev_offset]

        info.each do |abbrev_code|
          offset = abbrev_index[abbrev_code &- 1]

          DWARF.abbrev_at(abbrev_table + offset) do |abbrev|
            abbrev.each_attribute do |attr|
              info.skip_attribute_value(attr.form)
            end
          end
        end
      end

      # test: read attribute values (no unknown DW_FORM_*)
      DWARF.each_info(debug_info) do |info|
        abbrev_table = debug_abbrev + info.debug_abbrev_offset
        abbrev_index = abbrev_indexes[info.debug_abbrev_offset]

        info.each do |abbrev_code|
          offset = abbrev_index[abbrev_code &- 1]

          DWARF.abbrev_at(abbrev_table + offset) do |abbrev|
            abbrev.each_attribute do |attr|
              value = info.read_attribute_value(attr.form, attr.const_value)

              case attr.form
              when DWARF::DW_FORM_string, DWARF::DW_FORM_strp, DWARF::DW_FORM_line_strp
                # string values are valid, for example the offset correctly
                # points within the .debug_str or .debug_str_line sections or it
                # was correctly inlined
                assert_debug_str.call(attr.form, value)
              when DWARF::DW_AT_low_pc, DWARF::DW_AT_high_pc
                # TODO: verify that the PC is valid (points within the .text section)
              end
            end
          end
        end
      end
    end

    if debug_line
      DWARF.each_line_sequence(debug_line) do |seq|
        # directory table
        directories = 1

        seq.each_directory do |form, value|
          # verify that the string exists
          assert_debug_str.call(form, value)
          directories += 1
        end

        # file table
        files = 1
        seq.each_file do |(form, value), directory_index|
          # verify that the directory exists, and that the string exists
          directory_index.should be <= directories
          assert_debug_str.call(form, value)
          files += 1
        end

        # iterate file:line:column
        registers = DWARF::Line::Registers.new(seq.default_is_stmt?)
        seq.read_statement_program(pointerof(registers)) do
          # verify that the file exists
          registers.file.should be <= files
        end
      end
    end
  ensure
    program.try(&.close)
  end
end

describe Crystal::DWARF do
  fixtures_path = File.join(__DIR__, "dwarf")

  Dir.mkdir_p(fixtures_path)

  unless Dir.exists?(File.join(fixtures_path, "pyelftools"))
    status = Process.run %w[git clone --depth 1 https://github.com/eliben/pyelftools.git],
      chdir: fixtures_path, output: :inherit, error: :inherit
    abort "fatal: failed to clone https://github.com/eliben/pyelftools.git" unless status.success?
  end

  unless Dir.exists?(File.join(fixtures_path, "libdwarf-code"))
    status = Process.run %w[git clone --depth 1 https://github.com/davea42/libdwarf-code.git],
      chdir: fixtures_path, output: :inherit, error: :inherit
    abort "fatal: failed to clone https://github.com/davea42/libdwarf-code.git" unless status.success?
  end

  patterns = [
    "#{fixtures_path}/pyelftools/test/testfiles_for_*/**",
    "#{fixtures_path}/libdwarf-code/test/dummyexecutable",
    "#{fixtures_path}/libdwarf-code/test/dummyexecutable.debug",
    "#{fixtures_path}/libdwarf-code/test/test-mach-o-32.dSYM",
    "#{fixtures_path}/libdwarf-code/test/testobjLE32PE.exe",
    "#{fixtures_path}/libdwarf-code/test/testuriLE64ELf.testme",
  ]

  skip_files = [
    # doesn't parse: .debug_info reports unit_length=0 and header_length=0 (?)
    "loongarch64-relocs.o.elf",

    # compressed ELF sections aren't supported
    "compressed_unknown_type.o",
    "compressed_64.o",
    "compressed_bad_size.o",
  ]

  patterns.each do |pattern|
    Dir.glob(pattern).each do |path|
      next unless File.file?(path)

      if File.basename(path).in?(skip_files)
        pending(path)
      else
        it(path) { Crystal::DWARF.parse_debug_sections(path) }
      end
    end
  end
end
