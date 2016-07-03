local a = {}

function a:b(...)
   local a, self = 4

   do
      local a = (...)(a)
      each(a, function() local self = self[5]; return self.bar end)
   end

   print(a[1])
end

return a
