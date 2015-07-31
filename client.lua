local socket = require("socket");
local fs = require("filesystem");

local local_addr = "localhost"
local local_port = "5555"
local remote_addr = "localhost"
local remote_port = "5556"
local packet_size = 1024;

local source = "C:\\MinGW\\bin\\";
local dest = "c:\\luke\\LuaFileTransfer\\output\\";

local files = fs.listFiles(source);

local sock;
sock, err_msg = socket.udp();

if(sock == nil) then
  error("Failed to create socket: " .. err_msg);
end
local rc;
rc, err_msg = sock:setsockname(local_addr, local_port);
if( rc ~= 1) then
  error("Failed to setsockname to " .. local_addr .. ";" ..
    local_port .. ". Error: " .. err_msg);
end
rc, err_msg = sock:setpeername(remote_addr, remote_port);
if( rc ~= 1) then
  error("Failed to setpeername to " .. local_addr .. ";" ..
    local_port .. ". Error: " .. err_msg);
end
  
for file_name in files do
  local fd, err_msg = io.open(source .. file_name, "rb");
  if(fd == nil) then
    error("Can't open file " .. file_name .. ", error: " .. err_msg);
  end
  
  local header = "fn ";
  local packet = header .. dest .. file_name;
  sock:send(packet);
  print("Sent file name " .. packet);
  
  local contents = fd:read(packet_size);
  local next = fd:read(packet_size);
  local fend_payload = nil;
  
  while(next ~= nil) do
    local size = #contents
    if(size ~= packet_size) then
      error("Contents size wrong " .. tostring(size));
    end
    
    sock:send(contents);
    print("Sent full data " .. packet);
    contents = next;
    next = fd:read(packet_size);
  end
  
  packet = contents;
  local size = #contents;
  if( size ~= packet_size ) then
    local header = "fend ";
    local packet = header .. contents;
    
    if(#packet == packet_size) then
      packet = "fend2 " .. contents;
    end
    sock:send(packet);
    print("Sent fend with payload");
  else
    sock:send(packet);
    sock:send("fend ");
    print("Sent fend");
  end
  
end