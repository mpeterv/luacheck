Configuration file
==================

By default, ``luacheck`` tries to load configuration from ``.luacheckrc`` file in the current directory. Path to config can be set using ``--config`` option. Config loading can be disabled using ``--no-config`` flag.

Config is simply a Lua script executed by ``luacheck``. It may set various options by assigning to globals.

.. _options:

Config options
--------------

====================== ======================================= ==================
Option                 Type                                    Default value
====================== ======================================= ==================
``color``              Boolean                                 ``true``
``codes``              Boolean                                 ``false``
``limit``              Number                                  ``0``
``global``             Boolean                                 ``true``
``unused``             Boolean                                 ``true``
``redefined``          Boolean                                 ``true``
``unused_args``        Boolean                                 ``true``
``unused_values``      Boolean                                 ``true``
``unset``              Boolean                                 ``true``
``unused_secondaries`` Boolean                                 ``true``
``std``                String or array of strings              ``"_G"``
``globals``            Array of strings                        ``{}``
``new_globals``        Array of strings                        (Do not overwrite)
``read_globals``       Array of strings                        ``{}``
``new_read_globals``   Array of strings                        (Do not overwrite)
``compat``             Boolean                                 ``false``
``allow_defined``      Boolean                                 ``false``
``allow_defined_top``  Boolean                                 ``false``
``module``             Boolean                                 ``false``
``unused_globals``     Boolean                                 ``true``
``ignore``             Array of patterns (see :ref:`patterns`) ``{}``
``enable``             Array of patterns                       ``{}``
``only``               Array of patterns                       (Do not filter)
====================== ======================================= ==================

An example of a config which makes ``luacheck`` ensure that only globals from the portable intersection of Lua 5.1, Lua 5.2, Lua 5.3 and LuaJIT 2.0 are used, as well as disables detection of unused arguments:

.. code-block:: lua
   :linenos:

   std = "min"
   ignore = {"211"}

Per-prefix overrides
--------------------

The environment in which ``luacheck`` loads the config contains a special global ``files``. When checking a file ``<path>``, ``luacheck`` will override options from the main config with entries from ``files[<path_prefix>]``, applying entries for shorter prefixes first. This allows to override options for a specific file by setting ``files[<path>]``, and for all files in a directory by setting ``files[<dir>/]``. For example, the following config re-enables detection of unused arguments only for files in ``src/dir``, but not for ``src/dir/myfile.lua``:

.. code-block:: lua
   :linenos:

   std = "min"
   ignore = {"211"}

   files["src/dir/"] = {
      enable = {"211"}
   }

   files["src/dir/myfile.lua"] = {
      ignore = {"211"}
   }

Note that ``files`` table supports autovivification, so that

.. code-block:: lua

   files["myfile.lua"].ignore = {"211"}

and

.. code-block:: lua

   files["myfile.lua"] = {
      ignore = {"211"}
   }

are equivalent.
