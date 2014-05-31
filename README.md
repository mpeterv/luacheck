# luacheck

[![Build Status](https://travis-ci.org/mpeterv/luacheck.png?branch=master)](https://travis-ci.org/mpeterv/luacheck)

luacheck is a simple static analyzer for Lua. It only looks for three things: 

* non-standard global variables; 
* unused local variables(except variable named `_`, which should be used as placeholder when avoiding an unused variable is impossible) and values; 
* redefinitions of existing local variables in the same scope(e.g. `local a = 5; ... local a = 6`). 

luacheck provides a command-line interface as well as a small library which can be used from another Lua program. 

## Contents

* [Installation](#installation)
* [Command-line interface](#command-line-interface)
* [luacheck module](#luacheck-module)
* [Testing](#testing)
* [License](#license)

## Installation

Install luacheck using [luarocks](http://luarocks.org/): 

```bash
$ [sudo] luarocks install luacheck
```

## Command-line interface

```bash
$ luacheck --help
```

```
Usage: luacheck [-g] [-r] [-u] [-a] [-v] [--globals [<global>] ...]
       [-c] [-e] [--ignore <var> [<var>] ...]
       [--only <var> [<var>] ...] [-l <limit>] [-q] [-h]
       <file> [<file>] ...

luacheck 0.4.0, a simple static analyzer for Lua. 

Arguments: 
   files                 List of files to check. 

Options: 
   -g, --no-global       Do not check for accessing global variables. 
   -r, --no-redefined    Do not check for redefined variables. 
   -u, --no-unused       Do not check for unused variables. 
   -a, --no-unused-args  Do not check for unused arguments and loop variables. 
   -v, --no-unused-values
                         Do not check for unused values. 
   --globals [<global>] ...
                         Defined globals. Hyphen expands to standard globals. 
   -c, --compat          Adjust globals for Lua 5.1/5.2 compatibility. 
   -e, --ignore-env      Do not be _ENV-aware. 
   --ignore <var> [<var>] ...
                         Do not report warnings related to these variables. 
   --only <var> [<var>] ...
                         Only report warnings related to these variables. 
   -l <limit>, --limit <limit>
                         Exit with 0 if there are <limit> or less warnings. 
   -q, --quiet           Suppress output for files without warnings. 
                         -qq: Only print total number of warnings and errors. 
                         -qqq: Suppress output completely. 
   -h, --help            Show this help message and exit. 
```

```bash
$ luacheck *.lua
```

```
Checking bad_code.lua                             Failure

    bad_code.lua:3:16: unused variable helper
    bad_code.lua:3:23: unused variable length argument
    bad_code.lua:7:10: setting non-standard global variable embrace
    bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    bad_code.lua:9:11: accessing undefined variable hepler

Checking good_code.lua                            OK
Checking python_code.lua                          Syntax error

Total: 5 warnings / 1 error in 3 files
```

In CLI, rockspecs(arguments ending with `.rockspec`) expand into `.lua` files mentioned in them, so that

```bash
$ luacheck path/to/rockspec/rockname-1.0-1.rockspec
```

is a shortcut for checking all `rockname`-related files. 

CLI exits with `0` if no warnings or errors occured and with `1` otherwise. 

## luacheck module

`luacheck` module is a single function. 

The first argument is either a path to a file or an array of paths. 

If the second argument is provided, it should be a table of options. Recognized options are: 

* `options.check_global` - should luacheck check for global access? Default: `true`. 
* `options.check_redefined` - should luacheck check for redefined locals? Default: `true`. 
* `options.check_unused` - should luacheck check for unused locals and values? Default: `true`. 
* `options.check_unused_args` - should luacheck check for unused arguments and loop variables? Default: `true`. 
* `options.check_unused_values` - should luacheck check for unused values? Default: `true`. 
* `options.globals` - set of standard globals. Default: `_G`. 
* `options.env_aware` - ignore globals is chunks with custom `_ENV`. Default: `true`. 
* `options.ignore` - set of variables to ignore. Default: empty. Takes precedense over `options.only`. 
* `options.only` - set of variables to report. Default: report all variables. 

The function returns a report. A report is an array of per-file reports plus some meta information. Each per-file report is an array of warnings plus some meta information. 

```
report: {
   total = <total number of warnings>,
   errors = <total number of errors>,
   global = <total number of warnings related to global variables>,
   redefined = <total number of warnings related to redefined variables>,
   unused = <total number of warnings related to unused variables>,
   unused_value = <total number of warnings related to unused values>,
   <file_report>, <file_report>, ...
}

file_report: {
   file = <path to this file>,
   total = <number of warnings in this file>,
   global = <number of warnings related to global variables in this file>,
   redefined = <number of warnings related to redefined variables in this file>,
   unused = <number of warnings related to unused variables in this file>,
   unused_value = <number of warnings related to unused values in this file>,
   <warning>, <warning>, ...
} | {
   file = <path to this file>,
   error = "I/O" | "syntax"
}

warning: {
   type = "global" | "redefined" | "unused" | "unused_value",
   subtype = "access" | "set" | "var" | "arg" | "loop" | "vararg",
   name = <name of the related variable>,
   line = <number of the line where the problem occured>,
   column = <offset of the variable name in that line>,
   [prev_line = <number of the line of the previous definition for "redefined" warnings>,]
   [prev_column = <offset of the previous definition in that line>]
}
```

Example: 

```lua
local luacheck = require "luacheck"
local report = luacheck{"bad_code.lua", "good_code.lua", "python_code.lua"}
prettyprint(report)
```

```
{ { {
      column = 16,
      line = 3,
      name = "helper",
      subtype = "var",
      type = "unused"
    }, {
      column = 23,
      line = 3,
      name = "...",
      subtype = "vararg",
      type = "unused"
    }, {
      column = 10,
      line = 7,
      name = "embrace",
      subtype = "set",
      type = "global"
    }, {
      column = 10,
      line = 8,
      name = "opt",
      prev_column = 18,
      prev_line = 7,
      subtype = "arg",
      type = "redefined"
    }, {
      column = 11,
      line = 9,
      name = "hepler",
      subtype = "access",
      type = "global"
    },
    file = "bad_code.lua",
    global = 2,
    redefined = 1,
    total = 5,
    unused = 2,
    unused_value = 0
  }, {
    file = "good_code.lua",
    global = 0,
    redefined = 0,
    total = 0,
    unused = 0,
    unused_value = 0
  }, {
    error = "syntax",
    file = "python_code.lua"
  },
  errors = 1,
  global = 2,
  redefined = 1,
  total = 5,
  unused = 2,
  unused_value = 0
}
```

## Testing

You can run the tests using [busted](http://olivinelabs.com/busted/) with the following command from the root folder: 

```bash
$ busted spec
```

## License

```
The MIT License (MIT)

Copyright (c) 2014 Peter Melnichenko

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
