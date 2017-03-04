List of warnings
================

Warnings produced by Luacheck are categorized using three-digit warning codes. Warning codes can be displayed in CLI output using ``--codes`` CLI option or ``codes`` config option. Errors also have codes starting with zero.

==== =================================================================
Code Description
==== =================================================================
011  A syntax error.
021  An invalid inline option.
022  An unpaired inline push directive.
023  An unpaired inline pop directive.
111  Setting an undefined global variable.
112  Mutating an undefined global variable.
113  Accessing an undefined global variable.
121  Setting a read-only global variable.
122  Setting a read-only field of a global variable.
131  Unused implicitly defined global variable.
142  Setting an undefined field of a global variable.
143  Accessing an undefined field of a global variable.
211  Unused local variable.
212  Unused argument.
213  Unused loop variable.
221  Local variable is accessed but never set.
231  Local variable is set but never accessed.
232  An argument is set but never accessed.
233  Loop variable is set but never accessed.
241  Local variable is mutated but never accessed.
311  Value assigned to a local variable is unused.
312  Value of an argument is unused.
313  Value of a loop variable is unused.
314  Value of a field in a table literal is unused.
321  Accessing uninitialized local variable.
331  Value assigned to a local variable is mutated but never accessed.
341  Mutating uninitialized local variable.
411  Redefining a local variable.
412  Redefining an argument.
413  Redefining a loop variable.
421  Shadowing a local variable.
422  Shadowing an argument.
423  Shadowing a loop variable.
431  Shadowing an upvalue.
432  Shadowing an upvalue argument.
433  Shadowing an upvalue loop variable.
511  Unreachable code.
512  Loop can be executed at most once.
521  Unused label.
531  Left-hand side of an assignment is too short.
532  Left-hand side of an assignment is too long.
541  An empty ``do`` ``end`` block.
542  An empty ``if`` branch.
551  An empty statement.
611  A line consists of nothing but whitespace.
612  A line contains trailing whitespace.
613  Trailing whitespace in a string.
614  Trailing whitespace in a comment.
621  Inconsistent indentation (``SPACE`` followed by ``TAB``).
631  Line is too long.
==== =================================================================

Global variables
----------------

For each file, Luacheck builds list of defined globals and fields which can be used there. By default only globals from Lua standard library are defined; custom globals can be added using ``--globals`` CLI option or ``globals`` config option, and version of standard library can be selected using ``--std`` CLI option or ``std`` config option. When an undefined global or field is set, mutated or accessed, Luacheck produces a warning.

Read-only globals
^^^^^^^^^^^^^^^^^

By default, most standard globals and fields are marked as read-only, so that setting them produces a warning. Custom read-only globals and fields can be added using ``--read-globals`` CLI option or ``read_globals`` config option, or using a custom set of globals. See :ref:`custom_stds`

Globals and fields that are not read-only by default:

* ``_G``
* ``_ENV`` (treated as a global by Luacheck)
* ``package.path``
* ``package.cpath``
* ``package.loaded``
* ``package.preload``
* ``package.loaders``
* ``package.searchers``

.. _implicitlydefinedglobals:

Implicitly defined globals
^^^^^^^^^^^^^^^^^^^^^^^^^^

Luacheck can be configured to consider globals assigned under some conditions to be defined implicitly. When ``-d``/``--allow_defined`` CLI option or ``allow_defined`` config option is used, all assignments to globals define them; when ``-t``/``--allow_defined_top`` CLI option or ``allow_defined_top`` config option is used, assignments to globals in the top level function scope (also known as main chunk) define them. A warning is produced when an implicitly defined global is not accessed anywhere.

.. _modules:

Modules
^^^^^^^

Files can be marked as modules using ``-m``/``--module`` CLI option or ``module`` config option to simulate semantics of the deprecated `module <http://www.lua.org/manual/5.1/manual.html#pdf-module>`_ function. Globals implicitly defined inside a module are considired part of its interface, are not visible outside and are not reported as unused. Assignments to other globals are not allowed, even to defined ones.

Unused variables and values
---------------------------

Luacheck generates warnings for all unused local variables except one named ``_``. It also detects variables which are set but never accessed or accessed but never set.

Unused values and uninitialized variables
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For each value assigned to a local variable, Luacheck computes set of expressions where it could be used. Warnings are produced for unused values (when a value can't be used anywhere) and for accessing uninitialized variables (when no values can reach an expression). E.g. in the following snippet value assigned to ``foo`` on line 1 is unused, and variable ``bar`` is uninitialized on line 9:

.. code-block:: lua
   :linenos:

   local foo = expr1()
   local bar

   if condition() then
      foo = expr2()
      bar = expr3()
   else
      foo = expr4()
      print(bar)
   end

   return foo, bar

.. _secondaryvaluesandvariables:

Secondary values and variables
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Unused value assigned to a local variable is secondary if its origin is the last item on the RHS of assignment, and another value from that item is used. Secondary values typically appear when result of a function call is put into locals, and only some of them are later used. For example, here value assigned to ``b`` is secondary, value assigned to ``c`` is used, and value assigned to ``a`` is simply unused:

.. code-block:: lua
   :linenos:

   local a, b, c = f(), g()

   return c

A variable is secondary if all values assigned to it are secondary. In the snippet above, ``b`` is a secondary variable.

Warnings related to unused secondary values and variables can be removed using ``-s``/``--no-unused-secondaries`` CLI option or ``unused_secondaries`` config option.

Shadowing declarations
----------------------

Luacheck detects declarations of local variables shadowing previous declarations, unless the variable is named ``_``. If the previous declaration is in the same scope as the new one, it is called redefining.

Note that it is **not** necessary to define a new local variable when overwriting an argument:

.. code-block:: lua
   :linenos:

   local function f(x)
      local x = x or "default" -- bad
   end

   local function f(x)
      x = x or "default" -- good
   end

Control flow and data flow issues
---------------------------------

The following control flow and data flow issues are detected:

* Unreachable code and loops that can be executed at most once (e.g. due to an unconditional break);
* Unused labels;
* Unbalanced assignments;
* Empty blocks.
* Empty statements (semicolons without preceding statements).

Formatting issues
-----------------

Luacheck detects some common formatting issues, such as trailing whitespace and lines that are too long.
