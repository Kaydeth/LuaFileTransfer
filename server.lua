local socket = require("socket");

local sock = socket.udp();

sock:setsockname("localhost", 5555);
sock:setpeername("localhost", 5556);

print("Waiting for stuff");
local stuff = sock:receive();

print("got data: " .. stuff);