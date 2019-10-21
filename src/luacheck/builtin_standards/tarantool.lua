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
   'session',
   'stat',
   'priv',
}
local any_table = {other_fields = true}
for _, x in pairs(box_table_fields) do
   box_defs.fields[x] = any_table
end

return {fields = {
   box = box_defs,
   package = standards.def_fields(
      'setsearchroot',
      'searchroot',
      'search'
   ),
   table = standards.def_fields(
      'copy',
      'deepcopy'
   ),
}}