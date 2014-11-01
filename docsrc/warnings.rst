Types of warnings
=================

Luacheck generates warnings of three types:

* warnings related to global variables;
* warnings related to unused local variables and values;
* warnings related to redefined local variables.

Global variables
----------------

A global variable is defined if it is one of the standard globals (set using ``--std`` option in the command line and ``std`` option in the config) or custom globals (set using ``--globals`` option in the command line and ``globals`` option in the config).

When an undefined global variable is accessed or set, a warning of corresponding subtype is generated.

.. _allowdefined:

Implicit definition
^^^^^^^^^^^^^^^^^^^

If ``--allow_defined`` option is used, or ``allow_defined = true`` is in the config, global variables are automatically defined if they are set in one of the checked files. Luacheck will generate a warning if an implicitly defined global variable is never accessed.

Unused variables
----------------

Luacheck generates warnings for all unused local variables except one named ``_``. Detection of unused arguments and loop variables can be disabled using ``-a`` flag in the command line or ``unused_args = false`` in the config.

Unused values
^^^^^^^^^^^^^

Luacheck also detects unused values: redundant assignments to variables which are then not used before another assignment. As an example, in the following snippet value assigned to ``foo`` on line 4 is unused, as it is always overwritten on line 7:

.. code-block:: lua
   :linenos:

   local foo

   if condition() then
      foo = expr1()
   end

   foo = expr2()
   return foo

Redefined variables
-------------------

Luacheck detects declarations of local variables shadowing previous declarations in the same scope, unless the variable is named ``_``.

Note that it is **not** necessary to define a new local variable when overwritting an argument:

.. code-block:: lua
   :linenos:

   local function f(x)
      local x = x or "default" -- bad
   end

   local function f(x)
      x = x or "default" -- good
   end
