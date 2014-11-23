Types of warnings
=================

Luacheck generates warnings of three types:

* warnings related to global variables;
* warnings related to unused local variables and values;
* warnings related to redefined local variables.

Global variables
----------------

To determine whether an assignment to a global or accessing a global should produce a warning, Luacheck builds a list of defined globals for each file. Globals can be defined explicitly or implicitly. Accessing or setting an undefined global produces or warning of corresponding subtype. All warnings related to globals can be disabled using ``-g``/``--no-global`` CLI option or ``global`` config option.

Explicitly defined globals
^^^^^^^^^^^^^^^^^^^^^^^^^^

Explicitly defined globals consist of standard and custom globals. Standard globals are globals provided by Lua interpreter, and can be set using ``--std`` CLI option or ``std`` config option. Custom globals are globals accessible due to other reasons, and can be set using ``--globals`` CLI option or ``globals`` config option.

.. _implicitlydefinedglobals:

Implicitly defined globals
^^^^^^^^^^^^^^^^^^^^^^^^^^

Luacheck can be configured to consider globals assigned under some conditions to be defined implicitly. When ``-d``/``--allow_defined`` CLI option or ``allow_defined`` config option is used, all assignments to globals define them; when ``-t``/``--allow_defined_top`` CLI option or ``allow_defined_top`` config option is used, assignments to globals in the top level function scope (also known as main chunk) define them.

If an implicitly defined global is not accessed anywhere, a warning is produced, unless ``--no-unused-globals`` CLI option or ``unused_globals`` config option is used.

.. _modules:

Modules
^^^^^^^

Files can be marked as modules using ``-m``/``--module`` CLI option or ``module`` config option to simulate semantics of the deprecated `module <http://www.lua.org/manual/5.1/manual.html#pdf-module>`_ function. Globals implicitly defined inside a module are not visible outside and are not reported as unused. Additionally, only assignments to implicitly defined globals are allowed.

Unused variables
----------------

Luacheck generates warnings for all unused local variables except one named ``_``. These warnings can be disabled using ``-u``/``--no-unused`` CLI option or ``unused`` config option.

Detection of unused arguments and loop variables can be disabled using ``-a``/``--no-unused-args`` CLI option or ``unused_args`` config option.

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

Detection of unused values can be disabled using ``-v``/``--no-unused-values`` CLI option or ``unused_values`` config option.

.. _secondaryvaluesandvariables:

Secondary values and variables
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Unused value assigned to a local variable is secondary if its origin is the last item on the RHS of assignment, and another value from that item is used. Secondary values typically appear when result of a function call is put into locals, and only some of them are later used. For example, here value assigned to ``b`` is secondary, value assigned to ``c`` is used, and value assigned to ``a`` is simply unused:

.. code-block:: lua
   :linenos:

   local a, b, c = f(), g()

   return c

Secondary variables are unused variables initialized with a secondary value. In the snippet above, ``b`` is a secondary variable.

Warnings related to unused secondary values and variables can be removed using ``-s``/``--no-unused-secondaries`` CLI option or ``unused_secondaries`` config option.

Unset variables
^^^^^^^^^^^^^^^

Luacheck generates warnings for local variables that are accessed but never set. These warnings can be removed using ``--no-unset`` CLI option or ``unset`` config option.

Redefined variables
-------------------

Luacheck detects declarations of local variables shadowing previous declarations in the same scope, unless the variable is named ``_``. This diagnostic can be disabled using ``-r``/``--no-redefined`` CLI option or ``redefined`` config option.

Note that it is **not** necessary to define a new local variable when overwriting an argument:

.. code-block:: lua
   :linenos:

   local function f(x)
      local x = x or "default" -- bad
   end

   local function f(x)
      x = x or "default" -- good
   end
