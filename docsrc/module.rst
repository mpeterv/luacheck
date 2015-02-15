Luacheck module
===============

``luacheck`` module is a single function. Use ``local luacheck = require "luacheck"`` to import it.

The first argument of the function should be an array. Each element should be either a file name (string) or an open file handle, in which case ``luacheck`` will read it till EOF and close it.

The second argument, if present, should be a table of options. See :ref:`options`.

When checking ``n``-th file, ``luacheck`` will try to combine ``options[n]`` and entries from its array part with general options, similarly to how per file config tables overwrite main config table.

.. _report:

Report format
-------------

The ``luacheck`` function returns a report. A report is an array of file reports plus fields ``warnings`` and ``errors`` containing total number of warnings and errors, correspondingly.

A file report is an array of warnings. If an error occured while checking a file, its report will only have ``error`` field containing ``"I/O"`` or ``"syntax"``.

A warning is a table with field ``code`` indicating the type of warning (see :doc:`warnings`), and fields ``line`` and ``column`` pointing to the source of the warning. Absence of ``code`` field indicates that the warning is related to a broken inline configuration comment; then, ``invalid`` field marks comments with invalid syntax, and ``unpaired`` field marks unpaired push/pop comments.

Warnings of some types can also have additional fields:

===== =======================================================================================
Codes Additional fields
===== =======================================================================================
111   ``module`` field indicates that assignment is to a non-module global variable.
211   ``func`` field indicates that unused variable is a function.
212   ``vararg`` field indicated that variable length argument is unused.
4..   ``prev_line`` and ``prev_column`` fields contain location of the overwritten defintion.
===== =======================================================================================

Other fields may be present for internal reasons.
