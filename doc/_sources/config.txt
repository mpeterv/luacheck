Configuration file
==================

By default, ``luacheck`` tries to load configuration from ``.luacheckrc`` file in the current directory. Path to config can be set using ``--config`` option. Config loading can be disabled using ``--no-config`` flag.

Config format
-------------

Config is simply a Lua script executed by ``luacheck``. It may set various options by assigning to globals. See :ref:`options`.

An example of a config which makes ``luacheck`` ensure that only globals from the portable intersection of Lua 5.1, Lua 5.2 and LuaJIT 2.0 are used, as well as disables detection of unused arguments:

.. code-block:: lua
   :linenos:

   std = "min"
   unused_args = false

Per-file overrides
------------------

The environment in which ``luacheck`` loads the config contains a special global ``files``. When checking a file ``<path>``, ``luacheck`` will override options from the main config with entries from ``files[<path>]``. For example, the following config re-enables detection of unused arguments only for ``myfile.lua``:

.. code-block:: lua
   :linenos:

   std = "min"
   unused_args = false

   files["myfile.lua"] = {
      unused_args = true
   }

Note that ``files`` table supports autovivification, so that

.. code-block:: lua

   files["myfile.lua"].unused_args = true

and

.. code-block:: lua

   files["myfile.lua"] = {
      unused_args = true
   }

are equivalent.
