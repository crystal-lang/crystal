## RELPy v0.3.1

### Bug fixs
* Fix `REPLy` on Mac, caused by a wrong implementation of `ioctl`. Remake entirely the implementation of `Reply::Term::Size` in a more portable way. Inspired by (https://github.com/crystal-term/screen/blob/master/src/term-screen.cr.)

### Internals
* Compute the term-size only once for each input. Fix slow performance when the size is taken from `tput` (if `ioctl` fails).
* Fix spec on windows due to '\n\r'.
* Fix typo ('p' was duplicate in 'dupplicate').

## RELPy v0.3.0

### New features
* Windows support: REPLy is now working on Windows 10.
All features expect to work like linux except the key binding 'alt-enter'
that becomes 'ctrl-enter' on windows.
* Implement saving history in a file.
  * Add `Reader#history_file` which allow to specify the file location.
  * Add `History#max_size=` which allow to change the history max size. (default: 10_000)

### Internals
* Windows: use `GetConsoleScreenBufferInfo` for `Term::Size` and `ReadConsoleA` for
`read_char`.
* Windows: Disable some specs on windows.
* Small refactoring on `colorized_lines`.
* Refactor: Remove unneeded ivar `@max_prompt_size`.
* Improve performances for `move_cursor_to`.
* Remove unneeded ameba exception.
* Remove useless printing of `Term::Cursor.show` at exit.

## RELPy v0.2.1

### Bug fixs
* Reduce blinking on ws-code (computation are now done before clearing the screen). Disallow `sync` and `flush_on_newline` during `update` which help to reduce blinking too, (ic#10), thanks @cyangle!
* Align the expression when prompt size change (e.g. line number increase), which avoid a cursor bug in this case.
* Fix wrong history index after submitting an empty entry.

### Internal
* Write spec to avoid bug with autocompletion with '=' characters (ic#11), thanks @cyangle!

## RELPy v0.2.0

### New features

* BREAKING CHANGE: `word_delimiters` is now a `Array(Char)` property instead of `Regex` to return in a overridden function.
* `ctrl-n`, `ctrl-p` keybinding for navigate histories (#1), thanks @zw963!
* `delete_after`, `delete_before` (`ctrl-k`, `ctrl-u`) (#2), thanks @zw963!
* `move_word_forward`, `move_word_backward` (`alt-f`/`ctrl-right`, `alt-b`/`ctrl-left`) (#2), thanks @zw963!
* `delete_word`, `word_back` (`alt-backspace`/`ctrl-backspace`, `alt-d`/`ctrl-delete`) (#2), thanks @zw963!
* `delete` or `eof` on `ctrl-d` (#2), thanks @zw963!
* Bind `ctrl-b`/`ctrl-f` with move cursor backward/forward (#2), thanks @zw963!

### Bug fixs
* Fix ioctl window size magic number on darwin and bsd (#3), thanks @shinzlet!

### Internal
* Refactor: move word functions (`delete_word`, `move_word_forward`, etc.) from `Reader` to the `ExpressionEditor`.
* Add this CHANGELOG.

## RELPy v0.1.0
First version extracted from IC.

### New features
* Multiline input
* History
* Pasting of large expressions
* Hook for Syntax highlighting
* Hook for Auto formatting
* Hook for Auto indentation
* Hook for Auto completion (Experimental)
