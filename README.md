# luacheck

Simple static analyzer for Lua. 

```bash
$ git clone https://github.com/mpeterv/luacheck
$ cd luacheck
$ [sudo] luarocks make luarocks make rockspecs/luacheck-git-1.rockspec
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

