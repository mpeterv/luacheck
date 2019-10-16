rockspec_format = "3.0"
package = "rock2"
version = "dev-1"
source = {
   url = "https://github.com/rockman/rock2"
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
build = {}
test = {
  type = "busted"
}
