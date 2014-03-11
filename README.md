# luacheck

[![Build Status](https://travis-ci.org/mpeterv/luacheck.png?branch=master)](https://travis-ci.org/mpeterv/luacheck)

Simple static analyzer for Lua. 

```bash
$ git clone https://github.com/mpeterv/luacheck
$ cd luacheck
$ [sudo] luarocks make rockspecs/luacheck-git-1.rockspec
$ luacheck --help
```

```
Usage: luacheck [--globals <global> [<global>] ...] [-q] [-g] [-r]
       [-u] [-h] <file> [<file>] ...

Simple static analyzer. 

Arguments: 
   files                 Files to check. 

Options: 
   --globals <global> [<global>] ...
                         Defined globals. 
   -q, --quiet           Suppress output. 
   -g, --no-global       Do not check for accessing global variables. 
   -r, --no-redefined    Do not check for redefined variables. 
   -u, --no-unused       Do not check for unused variables. 
   -h, --help            Show this help message and exit. 
```

You will need metalua-parser rock. It is marked as not compatible with Lua 5.2, though it looks like it actaully is. So, if you use Lua 5.2, before installing luacheck, run

```bash
$ curl http://luarocks.org/repositories/rocks/metalua-parser-0.7.2-2.src.rock > metalua-parser-0.7.2-2.src.rock
$ unzip -o metalua-parser-0.7.2-2.src.rock
$ cd org.eclipse.koneki.metalua
$ sed -i 's/~>/>=/g' metalua-parser-0.7.2-2.rockspec
$ [sudo] luarocks make metalua-parser-0.7.2-2.rockspec
$ cd ..
$ rm org.eclipse.koneki.metalua -r
```

Things to do before release: 

* Write comprehensive test suite
* Write comprehensive documentation(LDoc)
* Ensure that metalua-parser is indeed Lua 5.2 compatible and ask to make a new release
* Add proper wildcards support to the CLI. There is no globbing library which works on nested wildcards(e.g. `src/*.lua`), write one?
