Configuration file
==================

``luacheck`` tries to load configuration from ``.luacheckrc`` file in the current directory. If not found, it will look for it in the parent directory and so on, going up until it reaches file system root. Path to config can be set using ``--config`` option, in which case it will be used during recursive loading. Config loading can be disabled using ``--no-config`` flag.

Config is simply a Lua script executed by ``luacheck``. It may set various options by assigning to globals or by returning a table with option names as keys.

.. _options:

Config options
--------------

====================== ======================================= ==================
Option                 Type                                    Default value
====================== ======================================= ==================
``color``              Boolean                                 ``true``
``codes``              Boolean                                 ``false``
``formatter``          String or function                      ``"default"``
``cache``              Boolean or string                       ``false``
``jobs``               Positive integer                        ``1``
``exclude_files``      Array of strings                        ``{}``
``include_files``      Array of strings                        (Include all files)
``global``             Boolean                                 ``true``
``unused``             Boolean                                 ``true``
``redefined``          Boolean                                 ``true``
``unused_args``        Boolean                                 ``true``
``unused_secondaries`` Boolean                                 ``true``
``self``               Boolean                                 ``true``
``std``                String or set of standard globals       ``"_G"``
``globals``            Array of strings                        ``{}``
``new_globals``        Array of strings                        (Do not overwrite)
``read_globals``       Array of strings                        ``{}``
``new_read_globals``   Array of strings                        (Do not overwrite)
``compat``             Boolean                                 ``false``
``allow_defined``      Boolean                                 ``false``
``allow_defined_top``  Boolean                                 ``false``
``module``             Boolean                                 ``false``
``ignore``             Array of patterns (see :ref:`patterns`) ``{}``
``enable``             Array of patterns                       ``{}``
``only``               Array of patterns                       (Do not filter)
``inline``             Boolean                                 ``true``
====================== ======================================= ==================

An example of a config which makes ``luacheck`` ensure that only globals from the portable intersection of Lua 5.1, Lua 5.2, Lua 5.3 and LuaJIT 2.0 are used, as well as disables detection of unused arguments:

.. code-block:: lua
   :linenos:

   std = "min"
   ignore = {"212"}

.. _custom_stds:


Custom sets of globals
----------------------

``std`` option allows setting a custom standard set of globals using a table. In that table, string keys are globals, and string in array part are read-only globals.

Additionally, custom sets can be given names by mutating global ``stds`` variable. For example, when using `LPEG <http://www.inf.puc-rio.br/~roberto/lpeg/>`_ library, it makes sense to access its functions tersely using globals. In that case, the following config allows removing false positives related to global access easily:

.. code-block:: lua
   :linenos:

   stds.lpeg = require "lpeg"

.. code-block:: lua
   :linenos:

   local lpeg = require "lpeg"

   local function parse1(...)
      -- This function only uses lpeg functions as globals.
      local _ENV = lpeg
      -- luacheck: std lpeg
      local digit, space = R "09", S " "
      -- ...
   end

   local function parse2(...)
      -- This function uses lpeg functions as well as standard globals.
      local _ENV = setmetatable({}, {__index = function(_, k) return _ENV[k] or lpeg[k] end})
      -- luacheck: std +lpeg
      local digit, space = R "09", S " "
      local number = C(digit^1) / tonumber
      -- ...
   end

Per-file and per-path overrides
-------------------------------

The environment in which ``luacheck`` loads the config contains a special global ``files``. When checking a file ``<path>``, ``luacheck`` will override options from the main config with entries from ``files[<path>]`` and ``files[<parent_path>]``, applying entries for shorter paths first. For example, the following config re-enables detection of unused arguments only for files in ``src/dir``, but not for ``src/dir/myfile.lua``, and allows using `Busted <http://olivinelabs.com/busted/>`_ globals within ``spec/``:

.. code-block:: lua
   :linenos:

   std = "min"
   ignore = {"212"}
   files["src/dir"] = {enable = {"212"}}
   files["src/dir/myfile.lua"] = {ignore = {"212"}}
   files["spec"] = {std = "+busted"}

Note that ``files`` table supports autovivification, so that

.. code-block:: lua

   files["myfile.lua"].ignore = {"212"}

and

.. code-block:: lua

   files["myfile.lua"] = {ignore = {"212"}}

are equivalent.
