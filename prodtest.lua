print(package.cpath);

package.path="./luasocket/lua/?.lua"
package.cpath="./luasocket/?.dll"

local socket = require("socket");