local socket = require("socket");

local sock = socket.udp();

sock:setsockname("localhost", 5556);
sock:setpeername("localhost", 5555);

sock:send("data");