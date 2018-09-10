rockspec_format = "3.0"
package = "rock"
version = "dev-1"
source = {
   url = "https://github.com/rockman/rock"
}
description = {
   license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
test_dependencies = {
  "busted = 2.0.rc12-1"
}
test = {
  type = "busted"
}
