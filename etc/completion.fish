set -l crystal_commands init build clear_cache docs env eval i interactive play run spec tool help version
set -l tool_subcommands context dependencies expand flags format hierarchy implementations types unreachable

complete -c crystal -s h -l help -d "Show help" -x

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "init" -d "Generate a new project"
complete -c crystal -f -n "__fish_seen_subcommand_from init" -a "lib" -d "Creates a library skeleton"
complete -c crystal -f -n "__fish_seen_subcommand_from init" -a "app" -d "Creates an application skeleton"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "build" -d "Build an executable"
complete -c crystal -n "__fish_seen_subcommand_from build" -l cross-compile -d "cross-compile"
complete -c crystal -n "__fish_seen_subcommand_from build" -s d -l debug -d "Add full symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from build" -l no-debug -d "Skip any symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from build" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from build" -l emit -d "Comma separated list of types of output for the compiler to emit" -a "asm obj llvm-bc llvm-ir" -f
complete -c crystal -n "__fish_seen_subcommand_from build" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from build" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from build" -l ll -d "Dump ll to Crystal's cache directory"
complete -c crystal -n "__fish_seen_subcommand_from build" -l link-flags -d "Additional flags to pass to the linker"
complete -c crystal -n "__fish_seen_subcommand_from build" -l mcpu -d "Target specific cpu type"
complete -c crystal -n "__fish_seen_subcommand_from build" -l mattr -d "Target specific features"
complete -c crystal -n "__fish_seen_subcommand_from build" -l mcmodel -d "Target specific code model"
complete -c crystal -n "__fish_seen_subcommand_from build" -l warnings -d "Which warnings detect. (default: all)" -a "all none" -f
complete -c crystal -n "__fish_seen_subcommand_from build" -l error-on-warnings -d "Treat warnings as errors"
complete -c crystal -n "__fish_seen_subcommand_from build" -l exclude-warnings -d "Exclude warnings from path (default: lib)"
complete -c crystal -n "__fish_seen_subcommand_from build" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from build" -l no-codegen -d "Don't do code generation"
complete -c crystal -n "__fish_seen_subcommand_from build" -s o -l output -d "Output filename"
complete -c crystal -n "__fish_seen_subcommand_from build" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from build" -l release -d "Compile in release mode"
complete -c crystal -n "__fish_seen_subcommand_from build" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from build" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from build" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from build" -l single-module -d "Generate a single LLVM module"
complete -c crystal -n "__fish_seen_subcommand_from build" -l threads -d "Maximum number of threads to use"
complete -c crystal -n "__fish_seen_subcommand_from build" -l target -d "Target triple"
complete -c crystal -n "__fish_seen_subcommand_from build" -l verbose -d "Display executed commands"
complete -c crystal -n "__fish_seen_subcommand_from build" -l static -d "Link statically"
complete -c crystal -n "__fish_seen_subcommand_from build" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "clear_cache" -d "clear the compiler cache"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "docs" -d "generate documentation"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l project-name -d "Set project name"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l project-version -d "Set project version"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l source-refname -d "Set source refname (e.g. git tag, commit hash)"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l source-url-pattern -d "Set URL pattern for source code links"
complete -c crystal -n "__fish_seen_subcommand_from docs" -s o -l output -d "Set the output directory (default: ./docs)"
complete -c crystal -n "__fish_seen_subcommand_from docs" -s f -l format -d "Set the output format (default: html)" -a "html json"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l json-config-url -d "Set the URL pointing to a config file (used for discovering versions)"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l canonical-base-url -d "Indicate the preferred URL with rel="canonical" link element"
complete -c crystal -n "__fish_seen_subcommand_from docs" -s b -l sitemap-base-url -d "Set the sitemap base URL and generates sitemap"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l sitemap-priority -d "Set the sitemap priority (default: 1.0)"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l sitemap-changefreq -d "Set the sitemap changefreq (default: never) "
complete -c crystal -n "__fish_seen_subcommand_from docs" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from docs" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from docs" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from docs" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l warnings -d "Which warnings detect (default: all)" -a "all none" -f
complete -c crystal -n "__fish_seen_subcommand_from docs" -l error-on-warnings -d "Treat warnings as errors"
complete -c crystal -n "__fish_seen_subcommand_from docs" -l exclude-warnings -d "Exclude warnings from path (default: lib)"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "env" -d "print Crystal environment information"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "eval" -d "eval code from args or standard input"
complete -c crystal -n "__fish_seen_subcommand_from eval" -s d -l debug -d "Add full symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l no-debug -d "Skip any symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from eval" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l release -d "Compile in release mode"
complete -c crystal -n "__fish_seen_subcommand_from eval" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from eval" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from eval" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l mcpu -d "Target specific cpu type"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l mattr -d "Target specific features"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l mcmodel -d "Target specific code model"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l warnings -d "Which warnings detect. (default: all)" -a "all none" -f
complete -c crystal -n "__fish_seen_subcommand_from eval" -l error-on-warnings -d "Treat warnings as errors"
complete -c crystal -n "__fish_seen_subcommand_from eval" -l exclude-warnings -d "Exclude warnings from path (default: lib)"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "i interactive" -d "starts interactive Crystal"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "play" -d "starts Crystal playground server"
complete -c crystal -n "__fish_seen_subcommand_from play" -s p -l port -d "Runs the playground on the specified port"
complete -c crystal -n "__fish_seen_subcommand_from play" -s b -l binding -d "Binds the playground to the specified IP"
complete -c crystal -n "__fish_seen_subcommand_from play" -s v -l verbose -d "Display detailed information of executed code"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "run" -d "build and run program"
complete -c crystal -n "__fish_seen_subcommand_from run" -s d -l debug -d "Add full symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from run" -l no-debug -d "Skip any symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from run" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from run" -l emit -d "Comma separated list of types of output for the compiler to emit" -a "asm obj llvm-bc llvm-ir" -f
complete -c crystal -n "__fish_seen_subcommand_from run" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from run" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from run" -l ll -d "Dump ll to Crystal's cache directory"
complete -c crystal -n "__fish_seen_subcommand_from run" -l link-flags -d "Additional flags to pass to the linker"
complete -c crystal -n "__fish_seen_subcommand_from run" -l mcpu -d "Target specific cpu type"
complete -c crystal -n "__fish_seen_subcommand_from run" -l mattr -d "Target specific features"
complete -c crystal -n "__fish_seen_subcommand_from run" -l mcmodel -d "Target specific code model"
complete -c crystal -n "__fish_seen_subcommand_from run" -l warnings -d "Which warnings detect. (default: all)" -a "all none" -f
complete -c crystal -n "__fish_seen_subcommand_from run" -l error-on-warnings -d "Treat warnings as errors"
complete -c crystal -n "__fish_seen_subcommand_from run" -l exclude-warnings -d "Exclude warnings from path (default: lib)"
complete -c crystal -n "__fish_seen_subcommand_from run" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from run" -l no-codegen -d "Don't do code generation"
complete -c crystal -n "__fish_seen_subcommand_from run" -s o -l output -d "Output filename"
complete -c crystal -n "__fish_seen_subcommand_from run" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from run" -l release -d "Compile in release mode"
complete -c crystal -n "__fish_seen_subcommand_from run" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from run" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from run" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from run" -l single-module -d "Generate a single LLVM module"
complete -c crystal -n "__fish_seen_subcommand_from run" -l threads -d "Maximum number of threads to use"
complete -c crystal -n "__fish_seen_subcommand_from run" -l verbose -d "Display executed commands"
complete -c crystal -n "__fish_seen_subcommand_from run" -l static -d "Link statically"
complete -c crystal -n "__fish_seen_subcommand_from run" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "spec" -d "build and run specs"
complete -c crystal -n "__fish_seen_subcommand_from spec" -s d -l debug -d "Add full symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l no-debug -d "Skip any symbolic debug info"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l release -d "Compile in release mode"
complete -c crystal -n "__fish_seen_subcommand_from spec" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from spec" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from spec" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l mcpu -d "Target specific cpu type"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l mattr -d "Target specific features"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l mcmodel -d "Target specific code model"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l warnings -d "Which warnings detect. (default: all)" -a "all none" -f
complete -c crystal -n "__fish_seen_subcommand_from spec" -l error-on-warnings -d "Treat warnings as errors"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l exclude-warnings -d "Exclude warnings from path (default: lib)"
complete -c crystal -n "__fish_seen_subcommand_from spec" -l link-flags -d "Additional flags to pass to the linker"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "tool" -d "run a tool"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "context" -d "show context for given location" -x
complete -c crystal -n "__fish_seen_subcommand_from context" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from context" -s c -l cursor -d "Cursor location with LOC as path/to/file.cr:line:column"
complete -c crystal -n "__fish_seen_subcommand_from context" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from context" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from context" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from context" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from context" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from context" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from context" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from context" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "dependencies" -d "show tree of required source files" -x
complete -c crystal -n "__fish_seen_subcommand_from context" -s i -l include -d "Include path in output"
complete -c crystal -n "__fish_seen_subcommand_from context" -s e -l exclude -d "Exclude path in output"
complete -c crystal -n "__fish_seen_subcommand_from context" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from context" -s f -l format -d "Output format 'tree' (default), 'flat', 'dot', or 'mermaid'." -a "tree flat dot mermaid" -f
complete -c crystal -n "__fish_seen_subcommand_from context" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from context" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from context" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from context" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from context" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from context" -s t -l time -d "Enable execution time output"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "expand" -d "show macro expansion for given location" -x
complete -c crystal -n "__fish_seen_subcommand_from expand" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from expand" -s c -l cursor -d "Cursor location with LOC as path/to/file.cr:line:column"
complete -c crystal -n "__fish_seen_subcommand_from expand" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from expand" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from expand" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from expand" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from expand" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from expand" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from expand" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from expand" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "flags" -d "print all macro 'flag?' values" -x

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "format" -d "format project, directories and/or files" -x
complete -c crystal -n "__fish_seen_subcommand_from format" -l check -d "Checks that formatting code produces no changes"
complete -c crystal -n "__fish_seen_subcommand_from format" -s i -l include -d "Include path"
complete -c crystal -n "__fish_seen_subcommand_from format" -s e -l exclude -d "Exclude path (default: lib)"
complete -c crystal -n "__fish_seen_subcommand_from format" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from format" -l show-backtrace -d "Show backtrace on a bug (used only for debugging)"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "hierarchy" -d "show type hierarchy" -x
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -s e -d "Filter types by NAME regex"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from hierarchy" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "implementations" -d "show implementations for given call in location" -x
complete -c crystal -n "__fish_seen_subcommand_from implementations" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -s c -l cursor -d "Cursor location with LOC as path/to/file.cr:line:column"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from implementations" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from implementations" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "unreachable" -d "show methods that are never called" -x
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s f -l format -d "Output format text (default), json, csv, codecov" -a "text json csv codecov" -f
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -l tallies -d "Print reachable methods and their call counts as well"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -l check -d "Exits with error if there is any unreachable code"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s i -l include -d "Include path"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s e -l exclude -d "Exclude path (default: lib)"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from unreachable" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "macro_code_coverage" -d "generate a macro code coverage report" -x
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s f -l format -d "Output format codecov (default)" -a "codecov" -f
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s i -l include -d "Include path"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s e -l exclude -d "Exclude path (default: lib)"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from macro_code_coverage" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "__fish_seen_subcommand_from tool; and not __fish_seen_subcommand_from $tool_subcommands" -a "types" -d "show type of main variables" -x
complete -c crystal -n "__fish_seen_subcommand_from types" -s D -l define -d "Define a compile-time flag"
complete -c crystal -n "__fish_seen_subcommand_from types" -s f -l format -d "Output format text (default) or json" -a "text json" -f
complete -c crystal -n "__fish_seen_subcommand_from types" -l error-trace -d "Show full error trace"
complete -c crystal -n "__fish_seen_subcommand_from types" -l no-color -d "Disable colored output"
complete -c crystal -n "__fish_seen_subcommand_from types" -l prelude -d "Use given file as prelude"
complete -c crystal -n "__fish_seen_subcommand_from types" -s s -l stats -d "Enable statistics output"
complete -c crystal -n "__fish_seen_subcommand_from types" -s p -l progress -d "Enable progress output"
complete -c crystal -n "__fish_seen_subcommand_from types" -s t -l time -d "Enable execution time output"
complete -c crystal -n "__fish_seen_subcommand_from types" -l stdin-filename -d "Source file name to be read from STDIN"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "help" -d "show help"

complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -a "version" -d "show version"
complete -c crystal -n "not __fish_seen_subcommand_from $crystal_commands" -s v -l version -d "show version" -x
