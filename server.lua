local socket = require("socket");
local fs = require("filesystem");

local local_addr = "localhost"
local local_port = "5556"
local remote_addr = "localhost"
local remote_port = "5555"
local packet_size = 1024;

local sock, err_msg = socket.udp();

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

print("Waiting for stuff");
local packet;
packet, err_msg = sock:receive();

local file_name = nil;
local fd = nil;
while(packet ~= nil) do
  local p_size = #packet;
  
  if(p_size == packet_size) then
      print("Got full data for " .. file_name);
    fd:write(packet);
  else
    local i = string.find(packet, " ");
    
    if( i == nil) then
      error("Cannot find packet header: " .. packet);
    end
    
    local command = string.sub(packet, 1, i - 1);
    
    if(command == "fn") then
      if( fd ~= nil) then
        error("File still open " .. file_name);
      end
      
      file_name = string.sub(packet, i + 1);
      print("Opening file " .. file_name);
      fd, err_msg = io.open(string.gsub(file_name, "\\", "\\\\"), "wb");
      
      if(fd == nil) then
        error("Can't open file, " .. file_name .. ": " .. err_msg);
      end
    elseif( command == "fend" or command == "fend2") then
      print("Closing file " .. file_name);
      fd:close();
      fd = nil;
      file_name = nil;
    end
  end
  
  packet, err_msg = sock:receive();
end