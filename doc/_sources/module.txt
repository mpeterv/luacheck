Luacheck module
===============

``luacheck`` module is a single function. Use ``local luacheck = require "luacheck"`` to import it.

The first argument of the function should be an array. Each element should be either a file name (string) or an open file handle, in which case ``luacheck`` will read it till EOF and close it.

.. _options:

Options
-------

The second argument, if present, should be a table of options. Options are interpreted similarly to corresponding command line switches; see :ref:`cliopts`.

============================== ========================== ===============
Option                         Type                       Default value
============================== ========================== ===============
``options.global``             Boolean                    ``true``
``options.redefined``          Boolean                    ``true``
``options.unused``             Boolean                    ``true``
``options.unused_args``        Boolean                    ``true``
``options.unused_values``      Boolean                    ``true``
``options.unused_secondaries`` Boolean                    ``true``
``options.unset``              Boolean                    ``true``
``options.std``                String or array of strings ``"_G"``
``options.globals``            Array of strings           ``{}``
``options.compat``             Boolean                    ``false``
``options.allow_defined``      Boolean                    ``false``
``options.allow_defined_top``  Boolean                    ``false``
``options.module``             Boolean                    ``false``
``options.unused_globals``     Boolean                    ``true``
``options.ignore``             Array of strings           ``{}``
``options.only``               Array of strings           (Do not filter)
============================== ========================== ===============

When checking ``n``-th file, ``luacheck`` will try to combine ``options[n]`` with general options, similarly to how per file config tables overwrite general config table. See :doc:`config`.

Report format
-------------

The ``luacheck`` function returns a report. A report is an array of file reports plus fields ``warnings`` and ``errors`` containing total number of warnings and errors, correspondingly.

A file report is an array of warnings. If an error occured while checking a file, its report will only have ``error`` field containing ``"I/O"`` or ``"syntax"``.

A warning is a table with fields ``type``, ``subtype`` and ``vartype`` indicating the type of warning (see :doc:`warnings`), and fields ``line`` and ``column`` pointing to the source of the warning. For warnings related to redefined variables there also are fields ``prev_line`` and ``prev_column`` pointing to the previous declaration of the variable.
