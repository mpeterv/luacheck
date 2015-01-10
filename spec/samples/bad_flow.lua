if io.read("*n") == "exit" then

else
   local a, b

   do
      -- print(something)
   end

   for _ = 1, 10 do
      if io.read("*n") == "foobar" then
         a, b = 1
         print(a, b)
         break
      else
         a, b = 1, 2, 3
         print(a, b)
         break
      end

      print("How could this happen?")
   end
end
