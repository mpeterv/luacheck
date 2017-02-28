stds = {
   my_server = {
      read_globals = {
         server = {
            fields = {
               bar = {read_only = false},
               baz = {},
               sessions = {read_only = false, other_fields = true}
            }
         }
      }
   }
}

read_globals = {
   server = {
      fields = {
         bar = {},
         baz = {read_only = false},
         sessions = {read_only = false, other_fields = true}
      }
   }
}
