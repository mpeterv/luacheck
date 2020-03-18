local standards = require "luacheck.standards"

local box_defs = standards.def_fields(
   'execute',
   'NULL',
   'once',
   'snapshot',
   -- https://www.tarantool.io/en/doc/2.2/book/box/box_txn_management/
   'atomic',
   'begin',
   'commit',
   'is_in_txn',
   'on_commit',
   'on_rollback',
   'rollback',
   'rollback_to_savepoint',
   'savepoint'
)

box_defs.fields.backup = standards.def_fields('start', 'stop')
box_defs.fields.runtime = standards.def_fields('info')
box_defs.fields.session = standards.def_fields(
   'id',
   'exists',
   'peer',
   'sync',
   'user',
   'type',
   'su',
   'uid',
   'euid',
   'on_connect',
   'on_disconnect',
   'on_auth',
   'push'
)
box_defs.fields.session.fields.storage = {other_fields = true, read_only = false}
box_defs.fields.slab = standards.def_fields('info', 'check', 'stats')

local box_table_fields = {
   'tuple',
   'schema',
   'feedback',
   'info',
   'ctl',
   'index',
   'internal',
   'error',
   'cfg',
   'space',
   'sequence',
   'stat',
   'priv',
}
local any_table = {other_fields = true}
for _, x in pairs(box_table_fields) do
   box_defs.fields[x] = any_table
end

return {fields = {
   _TARANTOOL = {},
   debug = standards.def_fields(
      'sourcedir',
      'sourcefile'
   ),
   dostring = {},
   box = box_defs,
   os = standards.def_fields(
      'environ',
      'setenv'
   ),
   package = standards.def_fields(
      'setsearchroot',
      'searchroot',
      'search'
   ),
   string = standards.def_fields(
      'center',
      'endswith',
      'fromhex',
      'hex',
      'ljust',
      'lstrip',
      'rjust',
      'rstrip',
      'split',
      'startswith',
      'strip'
   ),
   table = standards.def_fields(
      'copy',
      'deepcopy'
   ),
   tonumber64 = {},
}}
