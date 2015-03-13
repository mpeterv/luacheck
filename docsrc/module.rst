Luacheck module
===============

Use ``local luacheck = require "luacheck"`` to import ``luacheck`` module. It contains the following functions:

* ``luacheck.get_report(source)``: Given source string, returns analysis data (an array) or nil and syntax error table (table with fields ``line``, ``column``, ``offset``, ``msg``).
* ``luacheck.process_reports(reports, options)``: Processes array of analysis reports and applies options. ``reports[i]`` uses ``options``, ``options[i]``, ``options[i][1]``, ``options[i][2]``, ... as options, overriding each other in that order. Options table is a table with fields similar to config options; see :ref:`options`. Analysis reports with field ``error`` are ignored. ``process_reports`` returns final report, see :ref:`report`.
* ``luacheck.check_strings(sources, options)``: Checks array of sources using options, returns final report. Tables in ``sources`` array are ignored.
* ``luacheck.check_files(files, options)``: Checks array of files using options, returns final report. Open file handles can passed instead of filenames, in which case they will be read till EOF and closed.

``luacheck._VERSION`` contains Luacheck version as a string in ``MAJOR.MINOR.PATCH`` format.

Using ``luacheck`` as a function is equivalent to calling ``luacheck.check_files``.

.. _report:

Report format
-------------

A final report is an array of file reports plus fields ``warnings`` and ``errors`` containing total number of warnings and errors, correspondingly.

A file report is an array of warnings. If an error occured while checking a file, its report will have ``error`` field containing ``"I/O"`` or ``"syntax"``. In case of syntax error, ``line`` (number), ``colunmn`` (number), ``offset`` (number) and ``msg`` (string) fields are also present.

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
