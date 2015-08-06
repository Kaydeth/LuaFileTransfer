local filelink = {}

local socket = require("socket");
local sock_lib = require("sock_lib");

filelink.SERVER = "server";
filelink.CLIENT = "client";

local packet_size = 1024;  --bytes
local header_size = 8;  --bytes
local command_size = 3;   --bytes
local payload_size = packet_size - header_size;  --bytes

function filelink.create_link(link_type, local_addr, local_port, remote_addr, remote_port)
  local sock = nil;
 
  if(link_type == filelink.SERVER) then
    local listen_sock, err_msg = socket.tcp();

    if(listen_sock == nil) then
      error("Failed to create socket: " .. err_msg);
    end
    local rc;
    rc, err_msg = listen_sock:bind(local_addr, local_port);
    if( rc ~= 1) then
      error("Failed to bind to " .. local_addr .. ";" ..
        local_port .. ". Error: " .. err_msg);
    end

    local backlog = 1;
    rc, err_msg = listen_sock:listen(backlog);
    if( rc ~= 1 ) then
      error("Failed to listen on " .. local_addr .. ";" .. local_port .. ". Error:" .. err_msg);
    end

    print("Waiting for connection...");

    sock, err_msg = listen_sock:accept();
    if(sock == nil) then
      error("Failed to accept: " .. err_msg);
    end
    
    local remote_peer = sock:getpeername();
    print("Got connection from " .. remote_peer);
    
  elseif(link_type == filelink.CLIENT) then
    local err_msg = nil;
    sock, err_msg = socket.connect(remote_addr, remote_port);

    if( sock == nil) then
      error("Socket failed: " .. err_msg);
    end
  end
  
  return sock;
end

function filelink.send_file(link, source_file, dest_file)
  local fd, err_msg = io.open(source_file, "rb");
  if(fd == nil) then
    error("Can't open file " .. source_file .. ", error: " .. err_msg);
  end
  
  local header = string.format("fn %04d ", #dest_file);
  local packet = header .. dest_file;
  
  sock_lib.send_packet(link, packet);
    
  local contents = fd:read(payload_size);
  local next = fd:read(payload_size);
  
  local file_bytes = 0;
  while(true) do
    local size = #contents
    file_bytes = file_bytes + size;
    
    local packet = nil;
    local command = "py";
    
    if(next == nil) then
      command = "fd";
    end
  
    local header = string.format("%s %04d ", command, size);
    if(size ~= payload_size) then
      local padding = payload_size - size;
      packet = header .. contents .. string.rep(" ", padding);
    else
      packet = header .. contents;
    end
    
    --print("LSDEBUG: packet header: " .. string.sub(packet, 1, 8));
    if( #packet ~= packet_size) then
      error("Bad packet for file " .. source_file .. ". " .. #packet .. " bytes");
    end
    
    link:send(packet);
    
    if(next == nil) then
      break;
    end
    
    contents = next;
    next = fd:read(payload_size);
  end

  print(string.format("%s had %d bytes", source_file, file_bytes));
end

function filelink.recv_file(link)
  
  local file_name = nil;
  local fd = nil;
  local file_bytes = 0;
  while(true) do  
    local packet = nil;
    local expected_bytes = nil;
    
    if(fd ~= nil) then
      expected_bytes = packet_size;
      packet, err_msg = link:receive(packet_size);
    else
      expected_bytes = header_size;
      packet, err_msg = link:receive(header_size);
    end

    if(packet == nil) then
      error("Received nil: " .. err_msg);
    end
    
    if(#packet ~= expected_bytes) then
      error("Received unexpected number of bytes. Expected: " .. expected_bytes .. " got: " .. #packet);
    end
    
    local command = string.sub(packet, 1, command_size - 1);
    local payload_size_str = string.sub(packet, command_size + 1, header_size - 1);
    local payload_size = tonumber(payload_size_str);
    
    if(payload_size == nil) then
      error(string.format("Could not get payload size for command %s from string %s",
          command, tostring(payload_size_str)));
    end
    
    if(command == "py" or command == "fd") then
      fd:write(string.sub(packet, header_size + 1, header_size + payload_size));
      
      file_bytes = file_bytes + payload_size;
      
      if( command == "fd" ) then
        if( fd ~= nil) then
          error("Unexpected fd, file still open: " .. file_name);
        end

        print("Last packet for " .. file_name .. " has " .. payload_size .. " bytes");
        print("Closing file " .. file_name .. ". " .. file_bytes .. " bytes");
        fd:close();
        fd = nil;
        file_name = nil;
        
        break;
      end  
    elseif(command == "fn") then
      if( fd ~= nil) then
        error("File still open " .. file_name);
      end
      
      file_name, err_msg = link:receive(payload_size);
      if(file_name == nil) then
        error("Received nil: " .. err_msg);
      end
    
      print("Opening file " .. file_name);
      fd, err_msg = io.open(string.gsub(file_name, "\\", "\\\\"), "wb");
      
      if(fd == nil) then
        error("Can't open file, " .. file_name .. ": " .. err_msg);
      end
      
      file_bytes = 0;
    end
  end
end

return filelink