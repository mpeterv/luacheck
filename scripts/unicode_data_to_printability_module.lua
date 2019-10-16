-- Reads Unicode character data in UnicodeData.txt format from stdin.
-- Prints a Lua module retuning an array of first codepoints of
-- each continuous block of codepoints that are all printable or all not printable.
-- See https://unicode.org/reports/tr44/

local category_printabilities = {
   Lu = true,
   Ll = true,
   Lt = true,
   Lm = true,
   Lo = true,
   Mn = true,
   Mc = true,
   Me = true,
   Nd = true,
   Nl = true,
   No = true,
   Pc = true,
   Pd = true,
   Ps = true,
   Pe = true,
   Pi = true,
   Pf = true,
   Po = true,
   Sm = true,
   Sc = true,
   Sk = true,
   So = true,
   Zs = true,
   Zl = false,
   Zp = false,
   Cc = false,
   Cf = false,
   Cs = false,
   Co = false,
   Cn = false
}

local codepoint_printabilities = {}
local max_codepoint = 0

local range_start_codepoint

for line in io.lines() do
   local codepoint_hex, name, category = assert(line:match("^([^;]+);([^;]+);([^;]+)"))
   local codepoint = assert(tonumber("0x" .. codepoint_hex))
   local printability = category_printabilities[category]
   assert(printability ~= nil)

   if name:find(", First>$") then
      assert(not range_start_codepoint)
      range_start_codepoint = codepoint
   elseif name:find(", Last>$") then
      assert(range_start_codepoint and range_start_codepoint >= range_start_codepoint)

      for range_codepoint = range_start_codepoint, codepoint do
         codepoint_printabilities[range_codepoint] = printability
      end

      range_start_codepoint = nil
   else
      codepoint_printabilities[codepoint] = printability
   end

   max_codepoint = math.max(max_codepoint, codepoint)
end

assert(not range_start_codepoint)

local parts = {"return {"}
local prev_printability = true

-- Iterate up to a non-existent codepoint to ensure that the last required codepoint is printed.
for codepoint = 0, max_codepoint + 1 do
   local printability = codepoint_printabilities[codepoint] or false

   if printability ~= prev_printability then
      table.insert(parts, ("%d,"):format(codepoint))
   end

   prev_printability = printability
end

table.insert(parts, "}")
print(table.concat(parts))

