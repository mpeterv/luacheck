# Luacheck

[![Build Status](https://travis-ci.org/mpeterv/luacheck.png?branch=master)](https://travis-ci.org/mpeterv/luacheck)

Luacheck is a tool for linting and static analysis of [Lua](http://www.lua.org) code. It is able to spot usage of undefined global variables, unused local variables and a few other typical problems within Lua programs.

Luacheck provides a command line interface as well as a Lua module which can be used by other programs.

## Quick start

The easiest way to install Luacheck is to use [LuaRocks](http://luarocks.org). From your command line run the following command (you may want to prepend it with `sudo` on Linux):

```
$ luarocks install luacheck
```

After Luacheck is installed, run `luacheck` program from the command line. Pass a list of files or directories to be checked:

```
$ luacheck myfile.lua
Checking myfile.lua                               Failure

   myfile.lua:2:7: unused variable height
   myfile.lua:3:7: accessing undefined variable heigth

Total: 2 warnings / 0 errors in 1 file
```

## Documentation

Documentation is available [online](http://luacheck.readthedocs.org). If Luacheck has been installed using LuaRocks, it can be browsed offline using `luarocks doc luacheck` command.

## Development

Luacheck is currently in development. The latest released version is 0.6.0. The interface of the `luacheck` module may change between minor releases. The command line interface is fairly stable.

Use the Luacheck issue tracker on GitHub to submit bugs, suggestions and questions. Any pull requests are welcome, too.

## Building and testing

After the Luacheck repo is cloned and changes are made, run the following command (optionally prepended with `sudo`) from its root directory to install dev version of Luacheck. Replace `x` with the number of the latest scm rockspec in the `rockspecs` directory:

```
$ luarocks make rockspecs/luacheck-scm-x.rockspec
```

To test Luacheck, ensure that you have [busted](http://olivinelabs.com/busted) installed and run `busted spec`.

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
