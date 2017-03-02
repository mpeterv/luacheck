Luacheck module
===============

Use ``local luacheck = require "luacheck"`` to import ``luacheck`` module. It contains the following functions:

* ``luacheck.get_report(source)``: Given source string, returns analysis data (a table).
* ``luacheck.process_reports(reports, options)``: Processes array of analysis reports and applies options. ``reports[i]`` uses ``options``, ``options[i]``, ``options[i][1]``, ``options[i][2]``, ... as options, overriding each other in that order. Options table is a table with fields similar to config options; see :ref:`options`. Analysis reports with field ``fatal`` are ignored. ``process_reports`` returns final report, see :ref:`report`.
* ``luacheck.check_strings(sources, options)``: Checks array of sources using options, returns final report. Tables with field ``fatal`` within ``sources`` array are ignored.
* ``luacheck.check_files(files, options)``: Checks array of files using options, returns final report. Open file handles can passed instead of filenames, in which case they will be read till EOF and closed.
* ``luacheck.get_message(issue)``: Returns a string message for an issue, see :ref:`report`.

``luacheck._VERSION`` contains Luacheck version as a string in ``MAJOR.MINOR.PATCH`` format.

Using ``luacheck`` as a function is equivalent to calling ``luacheck.check_files``.

.. _report:

Report format
-------------

A final report is an array of file reports plus fields ``warnings``, ``errors`` and ``fatals`` containing total number of warnings, errors and fatal errors, correspondingly.

A file report is an array of issues (warnings or errors). If a fatal error occurred while checking a file, its report will have ``fatal`` field containing error type and ``msg`` field containing error message.

An issue is a table with field ``code`` indicating its type (see :doc:`warnings`), and fields ``line``, ``column`` and ``end_column`` pointing to the source of the warning. ``name`` field may contain name of related variable. Issues of some types can also have additional fields:

============= ========================================================================================
Codes         Additional fields
============= ========================================================================================
011           ``msg`` field contains syntax error message.
111           ``module`` field indicates that assignment is to a non-module global variable.
122, 142, 143 ``indirect`` field indicates that the global field was accessed using a local alias.
122, 142, 143 ``field`` field contains string representation of related global field.
211           ``func`` field indicates that unused variable is a function.
211           ``recursive`` field indicates that unused function is recursive.
211           ``mutually_recursive`` field is set for unused mutually recursive functions.
314           ``field`` field contains string representation of ununsed field or index.
4..           ``prev_line`` and ``prev_column`` fields contain location of the overwritten definition.
521           ``label`` field contains label name.
631           ``max_length`` field contains maximum allowed line length.
============= ========================================================================================

Other fields may be present for internal reasons.
