local socket = require("socket");
local fs = require("filesystem");

local local_addr = "localhost"
local local_port = "5555"
local remote_addr = "localhost"
local remote_port = "5556"

local source = "C:\\MinGW\\bin\\";
local dest = "c:\\luke\\LuaFileTransfer\\output\\";

local files = fs.listFiles(source);

for file_name in files do
  local fd, err_msg = io.open(source .. file_name, "rb");
  if(fd == nil) then
    error("Can't open file " .. file_name .. ", error: " .. err_msg);
  end
  
  local sock = socket.udp();
  sock:setsockname(local_addr, local_port);
  sock:setpeername(remote_addr, remote_port);
  
  local contents = fd:read(4096);
  while(contents ~= nil) do
    
    local ret, ret2 = out_fd:write(contents);
    contents = fd:read(4096);
 end
end