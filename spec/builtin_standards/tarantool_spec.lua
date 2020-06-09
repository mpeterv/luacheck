local luacheck = require "luacheck"

local function get_report(source, standard)
   source = source:gsub('\n%s+$', '\n')
   local report = luacheck.process_reports({luacheck.get_report(source)}, {std = standard or "tarantool"})
   local events = {}
   local slice_fields = {"code", "name", "field", "indexing"}
   for _, event in ipairs(report[1]) do
      local new_event = {}
      for _, field in ipairs(slice_fields) do
         new_event[field] = event[field]
      end
      table.insert(events, new_event)
   end
   return events
end

describe("Tarantool standard", function()
   it("differs from `max` standard", function()
      local source = [[
         box.backup.start()
         box.schema.space.create()
         package.setsearchroot()
         box.backup.invalid()
         package.invalid()
      ]]
      assert.same({
         {code = "143", name = "box", field = "backup.invalid", indexing = {"backup", "invalid"}},
         {code = "143", name = "package", field = "invalid", indexing = {"invalid"}},
      }, get_report(source))
      assert.same({
         {code = "113", name = "box", indexing = {"backup", "start"}},
         {code = "113", name = "box", indexing = {"schema", "space", "create"}},
         {code = "143", name = "package", field = "setsearchroot", indexing = {"setsearchroot"}},
         {code = "113", name = "box", indexing = {"backup", "invalid"}},
         {code = "143", name = "package", field = "invalid", indexing = {"invalid"}},
      }, get_report(source, "max"))
   end)

   it("knows all globals", function()
      -- local x = require('fun').iter(_G):totable() table.sort(x) return x
      assert.same({}, get_report([[
         print({
            _TARANTOOL,
            _VERSION,
            arg,
            assert,
            bit,
            box,
            collectgarbage,
            coroutine,
            debug,
            dofile,
            dostring,
            error,
            gcinfo,
            getfenv,
            getmetatable,
            io,
            ipairs,
            jit,
            load,
            loadfile,
            loadstring,
            math,
            module,
            newproxy,
            next,
            os,
            package,
            pairs,
            pcall,
            print,
            rawequal,
            rawget,
            rawset,
            require,
            select,
            setfenv,
            setmetatable,
            string,
            table,
            tonumber,
            tonumber64,
            tostring,
            type,
            unpack,
            xpcall,
         })
      ]]))
   end)

   it("knows all box fields", function()
      -- box.cfg{} local x = require('fun').iter(box):totable() table.sort(x) return x
      assert.same({}, get_report([[
         print({
            box.NULL,
            box.atomic,
            box.backup,
            box.begin,
            box.cfg,
            box.commit,
            box.ctl,
            box.error,
            box.execute,
            box.feedback,
            box.func,
            box.index,
            box.info,
            box.internal,
            box.is_in_txn,
            box.on_commit,
            box.on_rollback,
            box.once,
            box.prepare,
            box.priv,
            box.rollback,
            box.rollback_to_savepoint,
            box.runtime,
            box.savepoint,
            box.schema,
            box.sequence,
            box.session,
            box.slab,
            box.snapshot,
            box.space,
            box.stat,
            box.tuple,
            box.unprepare,
         })
      ]]))
   end)

   it('allows to write to box.session.storage', function()
      assert.same({
         {code = "143", name = "box", field = "session.invalid", indexing = {"session", "invalid"}},
      }, get_report([[
         box.session.storage.field1 = 1
         box.session.storage["field11"] = 1
         print(box.session.storage.field2, box.session.storage["field22"])
         box.session.push()
         box.session.invalid()
      ]]))
   end)
end)
