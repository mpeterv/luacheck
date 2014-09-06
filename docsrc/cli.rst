Command line interface
======================

``luacheck`` program accepts files, directories and `rockspecs <http://www.luarocks.org/en/Rockspec_format>`_ as arguments.

* Given a file, ``luacheck`` will check it.
* Given ``-``, ``luacheck`` will check stdin.
* Given a directory, ``luacheck`` will check all files with ``.lua`` extension within it.
* Given a rockspec (a file with ``.rockspec`` extension), ``luacheck`` will check all files with ``.lua`` extension mentioned in the rockspec in ``build.install.lua``, ``build.install.bin`` and ``build.modules`` tables.

The output of ``luacheck`` consists of separate reports for each checked file and ends with a summary::

   $ luacheck src
   Checking src/bad_code.lua                         Failure

       src/bad_code.lua:3:16: unused variable helper
       src/bad_code.lua:3:23: unused variable length argument
       src/bad_code.lua:7:10: setting non-standard global variable embrace
       src/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
       src/bad_code.lua:9:11: accessing undefined variable hepler

   Checking src/good_code.lua                        OK
   Checking src/python_code.lua                      Syntax error
   Checking src/unused_code.lua                      Failure

       src/unused_code.lua:3:18: unused argument baz
       src/unused_code.lua:4:8: unused loop variable i
       src/unused_code.lua:5:13: unused variable q
       src/unused_code.lua:7:11: unused loop variable a
       src/unused_code.lua:7:14: unused loop variable b
       src/unused_code.lua:7:17: unused loop variable c
       src/unused_code.lua:13:7: value assigned to variable x is unused
       src/unused_code.lua:14:1: value assigned to variable x is unused
       src/unused_code.lua:22:1: value assigned to variable z is unused

   Total: 14 warnings / 1 error in 4 files

``luacheck`` exits with 0 if no warnings or errors occured and with 1 otherwise.

.. _cliopts:

Command line options
--------------------

Short options that do not take an argument can be combined into one, so that ``-qqu`` is equivalent to ``-q -q -u``. For long options, both ``--option value`` or ``--option=value`` can be used.

Options taking several arguments can be used several time; ``--ignore foo --ignore bar`` is equivalent to ``--ignore foo bar``.

Note that options that may take several arguments, such as ``--globals``, should not be used immidiately before positional arguments; given ``--globals foo bar file.lua``, ``luacheck`` will consider all ``foo``, ``bar`` and ``file.lua`` global and then panic as there are no file names left.

==================================== =============================================================================
Option                               Meaning
==================================== =============================================================================
``-g`` | ``no-global``               Filter out warnings related to global variables.
``-r`` | ``no-redefined``            Filter out warnings related to redefined variables.
``-u`` | ``no-unused``               Filter out warnings related to unused variables.
``-a`` | ``no-unused-args``          Filter out warnings related to unused arguments and loop variables.
``-v`` | ``no-unused-values``        Filter out warnings related to unused values.
``--std <std>``                      Set standard globals. ``<std>`` must be one of:

                                     * ``_G`` - globals of the Lua interpreter ``luacheck`` runs on (default);
                                     * ``lua51`` - globals of Lua 5.1;
                                     * ``lua52`` - globals of Lua 5.2;
                                     * ``lua52c`` - globals of Lua 5.2 compiled with LUA_COMPAT_ALL;
                                     * ``luajit`` - globals of LuaJIT 2.0;
                                     * ``min`` - intersection of globals of Lua 5.1, Lua 5.2 and LuaJIT 2.0;
                                     * ``max`` - union of globals of Lua 5.1, Lua 5.2 and LuaJIT 2.0;
                                     * ``none`` - no standard globals.
``--globals [<global>] ...``         Add custom globals on top of standard ones.
``--new-globals [<global>] ...``     Set custom globals. Removes custom globals added previously.
``-c`` | ``--compat``                Equivalent to ``--std=max``.
``-d`` | ``--allow-defined``         Allow defining globals by setting them. See :ref:`allowdefined`.
``--no-unused-globals``              Filter out warnings related to set but unused global variables.
``--ignore <var> [<var>] ...``       Filter out warnings related to variables named ``<var>``.
``--only <var> [<var>] ...``         Filter out warnings not related to variables named ``<var>``.
``-l <limit>`` | ``--limit <limit>`` Exit with 0 if there are ``<limit>`` or less warnings (default: ``0``).
``--config <config>``                Path to custom configuration file (default: ``.luacheckrc``).
``--no-config``                      Do not look up custom configuration file.
``-q`` | ``--quiet``                 Suppress report output for files without warnings.

                                     * ``-qq`` - Suppress output of warnings.
                                     * ``-qqq`` - Only output summary.
``--no-color``                       Do not colorize output.
``-h`` | ``--help``                  Show help and exit.
==================================== =============================================================================
