# Luacheck

[![Join the chat at https://gitter.im/luacheck/Lobby](https://badges.gitter.im/luacheck/Lobby.svg)](https://gitter.im/luacheck/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Luacheck](https://img.shields.io/github/workflow/status/lunarmodules/luacheck/Luacheck?label=Luacheck&logo=Lua)](https://github.com/lunarmodules/luacheck/actions?workflow=Luacheck)
[![Busted](https://img.shields.io/github/workflow/status/lunarmodules/luacheck/Busted?label=Busted&logo=Lua)](https://github.com/lunarmodules/luacheck/actions?workflow=Busted)
[![Coverage Status](https://img.shields.io/coveralls/github/lunarmodules/luacheck?label=Coveralls&logo=Coveralls)](https://coveralls.io/github/lunarmodules/luacheck?branch=master)
[![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/lunarmodules/luacheck?label=Tag&logo=GitHub)](https://github.com/lunarmodules/luacheck/releases)
[![Luarocks](https://img.shields.io/luarocks/v/lunarmodules/luacheck?label=Luarocks&logo=Lua)](https://luarocks.org/modules/lunarmodules/luacheck)

## Contents

* [Overview](#overview)
* [Installation](#installation)
* [Basic usage](#basic-usage)
* [Related projects](#related-projects)
* [Documentation](#documentation)
* [Development](#development)
* [Building and testing](#building-and-testing)
* [License](#license)

## Overview

Luacheck is a static analyzer and a linter for [Lua](http://www.lua.org). Luacheck detects various issues such as usage of undefined global variables, unused variables and values, accessing uninitialized variables, unreachable code and more. Most aspects of checking are configurable: there are options for defining custom project-related globals, for selecting set of standard globals (version of Lua standard library), for filtering warnings by type and name of related variable, etc. The options can be used on the command line, put into a config or directly into checked files as Lua comments.

Luacheck supports checking Lua files using syntax of Lua 5.1 - 5.4, and LuaJIT. Luacheck itself is written in Lua and runs on all of mentioned Lua versions.

## Installation

### Using LuaRocks

From your command line run the following command (using `sudo` if necessary):

```
luarocks install luacheck
```

For parallel checking Luacheck additionally requires [LuaLanes](https://github.com/LuaLanes/lanes), which can be installed using LuaRocks as well (`luarocks install lanes`).

### Windows binary download

For Windows there is single-file 64-bit binary distribution, bundling Lua 5.4.4, Luacheck, LuaFileSystem, and LuaLanes using [LuaStatic](https://github.com/ers35/luastatic):
[download](https://github.com/lunarmodules/luacheck/releases/download/0.26.1/luacheck.exe).

## Basic usage

After Luacheck is installed, run `luacheck` program from the command line. Pass a list of files, [rockspecs](https://github.com/luarocks/luarocks/wiki/Rockspec-format) or directories (requires LuaFileSystem) to be checked:

```
luacheck src extra_file.lua another_file.lua
```

```
Checking src/good_code.lua               OK
Checking src/bad_code.lua                3 warnings

    src/bad_code.lua:3:23: unused variable length argument
    src/bad_code.lua:7:10: setting non-standard global variable embrace
    src/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7

Checking src/python_code.lua             1 error

    src/python_code.lua:1:6: expected '=' near '__future__'

Checking extra_file.lua                  5 warnings

    extra_file.lua:3:18: unused argument baz
    extra_file.lua:4:8: unused loop variable i
    extra_file.lua:13:7: accessing uninitialized variable a
    extra_file.lua:14:1: value assigned to variable x is unused
    extra_file.lua:21:7: variable z is never accessed

Checking another_file.lua                2 warnings

    another_file.lua:2:7: unused variable height
    another_file.lua:3:7: accessing undefined variable heigth

Total: 10 warnings / 1 error in 5 files
```

For more info, see [documentation](https://luacheck.readthedocs.io/en/stable/).

## Related projects

### Editor support

There are a few plugins which allow using Luacheck directly inside an editor, showing warnings inline:

* For Vim, [Syntastic](https://github.com/vim-syntastic/syntastic) contains [luacheck checker](https://github.com/vim-syntastic/syntastic/wiki/Lua%3A---luacheck);
* For Sublime Text 3 there is [SublimeLinter-luacheck](https://packagecontrol.io/packages/SublimeLinter-luacheck) which requires [SublimeLinter](https://sublimelinter.readthedocs.io/en/latest/);
* For Atom there is [linter-luacheck](https://atom.io/packages/linter-luacheck) which requires [AtomLinter](https://github.com/steelbrain/linter);
* For Emacs, [Flycheck](http://www.flycheck.org/en/latest/) contains [luacheck checker](http://www.flycheck.org/en/latest/languages.html#lua);
* For Brackets, there is [linter.luacheck](https://github.com/Malcolm3141/brackets-luacheck) extension;
* For Visual Studio code there is [vscode-luacheck](https://marketplace.visualstudio.com/items?itemName=dwenegar.vscode-luacheck) extension. [vscode-lua](https://marketplace.visualstudio.com/items?itemName=trixnz.vscode-lua) extension also includes Luacheck support;
* For Nova, search the Extension Library for the [Luacheck](https://github.com/GarrettAlbright/Luacheck.novaextension) extension.

If you are a plugin developer, see [recommended way of using Luacheck in a plugin](http://luacheck.readthedocs.org/en/stable/cli.html#stable-interface-for-editor-plugins-and-tools).

### Other projects

* [Luacheck bindings for Node.js](https://www.npmjs.com/package/luacheck);
* [Luacheck plugin for Gulp](https://www.npmjs.com/package/gulp-luacheck).

## Documentation

Documentation is available [online](https://luacheck.readthedocs.io/en/stable/). If Luacheck has been installed using LuaRocks, it can be browsed offline using `luarocks doc luacheck` command.

Documentation can be built using [Sphinx](http://sphinx-doc.org/): `sphinx-build docsrc doc`, the files will be found inside `doc/`.

## Development

Luacheck is currently in development. The latest released version is 0.26.1. The interface of the `luacheck` module may change between minor releases. The command line interface is fairly stable.

Use the Luacheck issue tracker on GitHub to submit bugs, suggestions and questions. Any pull requests are welcome, too.

## Building and testing

After the Luacheck repo is cloned and changes are made, run `luarocks make` (using `sudo` if necessary) from its root directory to install dev version of Luacheck. To run Luacheck using sources in current directory without installing it, run `lua -e 'package.path="./src/?.lua;./src/?/init.lua;"..package.path' bin/luacheck.lua ...`. To test Luacheck, ensure that you have [busted](http://olivinelabs.com/busted/) and [luautf8](https://github.com/starwing/luautf8) installed and run `busted`.

## Docker

Alternatively Luacheck can be run as a standalone docker container.
The usage of docker is fairly simple.
You can either build your own or download a prebuilt version.
To build your own, execute the following command from the source directory of this project:

```console
$ docker build -t ghcr.io/lunarmodules/luacheck:HEAD .
```

To use a prebuilt one, download it from the GitHub Container Registry.
Here we use the one tagged *latest*, but you can substitute *latest* for any tagged release.

```console
$ docker pull ghcr.io/lunarmodules/luacheck:latest
```

Once you have a container you can run it on one file or a source tree (substitute *latest* with *HEAD* if you built your own or with the tagged version you want if applicable):

```console
# Run on an entire directory
$ docker run -v "$(pwd):/data" ghcr.io/lunarmodules/luacheck:latest .

# Run on one file:
$ docker run -v "$(pwd):/data" ghcr.io/lunarmodules/luacheck:latest bin/luacheck.lua
```

A less verbose way to run it in most shells is with at alias:

```console
# In a shell or in your shell's RC file:
$ alias luacheck='docker run -v "$(pwd):/data" ghcr.io/lunarmodules/luacheck:latest'

# Thereafter just run:
$ luacheck .
```
### Use as a CI job

There are actually many ways to run Luacheck remotely as part of a CI work flow.
Because packages are available for many platforms, one way would be to just use your platforms native package installation system to pull them into whatever CI runner environment you already use.
Another way is to pull in the prebuilt Docker container and run that.

As a case study, here is how a workflow could be setup in GitHub Actions:

```yaml
name: Luacheck
on: [push, pull_request]
jobs:
  sile:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Luacheck linter
        uses: lunarmodules/luacheck@v0
```

By default the GH Action is configured to run `luacheck .`, but you can also pass it your own `args` to replace the default input of `.`.

```yaml
      - name: Luacheck linter
        uses: lunarmodules/luacheck@v0
        with:
            args: myfile.lua
```

## License

```
The MIT License (MIT)

Copyright (c) 2014 - 2018 Peter Melnichenko

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
