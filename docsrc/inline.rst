Inline options
==============

Luacheck supports setting some options directly in the checked files using inline configuration comments. An inline configuration comment starts with ``luacheck:`` label, possibly after some whitespace. The body of the comment should contain comma separated options, where option invocation consists of its name plus space separated arguments. The following options are supported:

================= ============================================
Option            Number of arguments
================= ============================================
compat            0
module            0
allow_defined     0
allow_defined_top 0
std               1
globals           0+
new_globals       0+
read_globals      0+
new_read_globals  0+
ignore            0+ (without arguments everything is ignored)
enable            1+
only              1+
================= ============================================

Part of the file affected by inline option dependes on where it is placed. If there is any code on the line with the option, only that line is affected; otherwise, everthing till the end of the current closure is. In particular, inline options at the top of the file affect all of it:

.. code-block:: lua
   :linenos:

   -- luacheck: globals g1 g2, ignore foo
   local foo = g1(g2) -- No warnings emitted.

   -- The following unused function is not reported.
   local function f() -- luacheck: ignore
      -- luacheck: globals g3
      g3() -- No warning.
   end
   
   g3() -- Warning is emitted as the inline option defining g3 only affected function f.

For fine-grained control over inline option visibility use ``luacheck: push`` and ``luacheck: pop`` directives:

.. code-block:: lua
   :linenos:

   -- luacheck: push
   -- luacheck: ignore foo
   foo() -- No warning.
   -- luacheck: pop
   foo() -- Warning is emitted.

Inline options can be completely disabled using ``--no-inline`` CLI option or ``inline`` config option.
