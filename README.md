# luacheck

[![Build Status](https://travis-ci.org/mpeterv/luacheck.png?branch=master)](https://travis-ci.org/mpeterv/luacheck)

luacheck is a simple static analyzer for Lua. It only looks for three things: 

* non-standard global variables; 
* unused local variables(except variable named `_`, which should be used as placeholder when avoiding an unused variable is impossible); 
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
Usage: luacheck
       ([--ignore <var> [<var>] ...] | [--only <var> [<var>] ...])
       [--globals <global> [<global>] ...] [-q] [-g] [-r] [-u]
       [--no-unused-args] [-h] <file> [<file>] ...

Simple static analyzer. 

Arguments: 
   files                 Files to check. 

Options: 
   --globals <global> [<global>] ...
                         Defined globals. 
   --ignore <var> [<var>] ...
                         Do not report warnings related to these variables. 
   --only <var> [<var>] ...
                         Only report warnings related to these variables. 
   -q, --quiet           Suppress output. 
   -g, --no-global       Do not check for accessing global variables. 
   -r, --no-redefined    Do not check for redefined variables. 
   -u, --no-unused       Do not check for unused variables. 
   --no-unused-args      Do not check for unused arguments and loop variables. 
   -h, --help            Show this help message and exit. 
```

```bash
$ luacheck *.lua
```

```
Checking bad_code.lua                             Failure

    bad_code.lua:3:16: unused variable helper
    bad_code.lua:7:10: accessing undefined variable embrace
    bad_code.lua:8:10: variable opt was previously defined in the same scope
    bad_code.lua:9:11: accessing undefined variable hepler

Checking good_code.lua                            OK
Checking python_code.lua                          Error

Total: 4 warnings / 1 error
```

CLI exits with `0` if no warnings or errors occured and with `1` otherwise. 

## luacheck module

`luacheck` module is a single function. 

The first argument is either a path to a file or an array of paths. 

If the second argument is provided, it should be a table of options. Recognized options are: 

* `options.check_global` - should luacheck check for global access? Default: `true`. 
* `options.check_redefined` - should luacheck check for redefined locals? Default: `true`. 
* `options.check_unused` - should luacheck check for unused locals? Default: `true`. 
* `options.check_unused_args` - should luacheck check for unused arguments and loop variables? Default: `true`. 
* `options.globals` - set of standard globals. Default: `_G`. 
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
   <file_report>, <file_report>, ...
}

file_report: {
   file = <path to this file>,
   total = <number of warnings in this file>,
   global = <number of warnings related to global variables in this file>,
   redefined = <number of warnings related to redefined variables in this file>,
   unused = <number of warnings related to unused variables in this file>,
   <warning>, <warning>, ...
} | {
   file = <path to this file>,
   error = true
}

warning: {
   type = "global" | "redefined" | "unused",
   name = <name of the related variable>,
   line = <number of the line where the problem occured>,
   column = <offset of the variable name in that line>
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
      type = "unused"
    }, {
      column = 10,
      line = 7,
      name = "embrace",
      type = "global"
    }, {
      column = 10,
      line = 8,
      name = "opt",
      type = "redefined"
    }, {
      column = 11,
      line = 9,
      name = "hepler",
      type = "global"
    },
    file = "bad_code.lua",
    global = 2,
    redefined = 1,
    total = 4,
    unused = 1
  }, {
    file = "good_code.lua",
    global = 0,
    redefined = 0,
    total = 0,
    unused = 0
  }, {
    error = true,
    file = "python_code.lua"
  },
  errors = 1,
  global = 2,
  redefined = 1,
  total = 4,
  unused = 1
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
