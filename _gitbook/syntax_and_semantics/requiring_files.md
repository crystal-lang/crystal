# Requiring files

Writing a program in a single file is OK for little snippets and small benchmark code. Big programs are better maintained and understood when split across different files.

To make the compiler process other files you use `require "..."`. It accepts a single argument, a string literal, and it can come in many flavors.

Once a file is required, the compiler remembers its absolute path and later `require`s of that same file will be ignored.

## require "filename"

This looks up "filename" in the require path.

By default the require path is the location of the standard library that comes with the compiler, and the "libs" directory relative to the current working directory (given by `pwd` in a unix shell). These are the only places that are looked up.

The lookup goes like this:

* If a file named "filename.cr" is found in the require path, it is required.
* If a directory named "filename" is found and it contains a file named "filename.cr" directly underneath it, it is required.
* Otherwise a compile-time error is issued.

The second rule is very convenient because of the typical directory structure of a project:

```
- project
  - libs
    - foo
      foo.cr
    - bar
      bar.cr
  - src
    - project.cr
  - spec
    - project_spec.cr
```

## require "./filename"

This looks up "filename" relative to the file containing the require expression.

The lookup goes like this:

* If a file named "filename.cr" is found relative to the current file, it is required.
* If a directory named "filename" is found and it contains a file named "filename.cr" directly underneath it, it is required.
* Otherwise a compile-time error is issued.

This relative is mostly used inside a project to refer to other files inside it. It is also used to refer to code from specs:

```ruby
# in spec/project_spec.cr
require "../src/project"
```

## Other forms

In both cases you can use nested names and they will be looked up in nested directories:

* `require "foo/bar/baz"` will lookup "foo/bar/baz.cr" or "foo/bar/baz/baz.cr" in the require path.
* `require "./foo/bar/baz"` will lookup "foo/bar/baz.cr" or "foo/bar/baz/baz.cr" relative to the current file.

You can also use "../" to access parent directories relative to the current file, so `require "../../foo/bar"` works as well.

In all of these cases you can use the special `*` and `**` suffixes:

* `require "foo/*"` will require all ".cr" files below the "foo" directory, but not below directories inside "foo".
* `require "foo/**"` will require all ".cr" files below the "foo" directory, and below directories inside "foo", recursively.
