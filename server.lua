print("LSDEBUG: " .. package.path);

package.path="./?.lua;./luasocket/lua/?.lua"
package.cpath="./luasocket/?.dll"

local filelink = require("filelink");
local fs = require("filesystem");
local log = require("log");

log.open_log();
log.info("Server started");

local local_addr = "localhost"
local local_port = "16000"
local remote_addr = "localhost"
local remote_port = "15000"

local link = filelink.create_link(filelink.SERVER, local_addr, local_port);

print("Waiting for stuff");

filelink.command_loop(link);
