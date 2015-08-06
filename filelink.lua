local filelink = {}

local socket = require("socket");
local sock_lib = require("sock_lib");

filelink.SERVER = "server";
filelink.CLIENT = "client";

filelink.IDLE_STATE = "idle";
filelink.RECV_FILE_STATE = "file";
filelink.RECV_FILE_LIST_STATE = "filelist";

local packet_size = 1024;  --bytes
local header_size = 8;  --bytes
local command_size = 3;   --bytes
local payload_size = packet_size - header_size;  --bytes

function filelink.create_link(link_type, local_addr, local_port, remote_addr, remote_port)
  local link = { sock = nil, state = nil, file = nil, dir = nil, };
  local file = { file_name = nil, open_fd = nil, file_bytes = 0 };
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
  
  link.sock = sock;
  link.state = filelink.IDLE_STATE;
  return link;
end

function filelink.command_loop(link)
  local expected_bytes = header_size;

  while(true) do  
    local packet = nil;
    
    packet, err_msg = link.sock:receive(expected_bytes);
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
    
    expected_bytes = filelink.processCommand(link, command, payload_size, packet);
  end
end

function filelink.processCommand(link, command, payload_size, packet)
    if(command == "py") then
      
      if(link.state ~= filelink.RECV_FILE_STATE) then
        error(string.format("Unexpected command %s in state %s", command, link.state));
      end
      
      local file = link.file;
      file.open_fd:write(string.sub(packet, header_size + 1, header_size + payload_size));
      
      file.file_bytes = file.file_bytes + payload_size;      
      
      return packet_size;
    elseif(command == "fd") then
      
      if(link.state ~= filelink.RECV_FILE_STATE) then
        error(string.format("Unexpected command %s in state %s", command, link.state));
      end

      local file = link.file;

      file.open_fd:write(string.sub(packet, header_size + 1, header_size + payload_size));
      
      file.file_bytes = file.file_bytes + payload_size;      
      
      if( file.open_fd == nil) then
        error("Unexpected fd command, file not open: " .. tostring(file.file_name));
      end

      print("Last packet for " .. file.file_name .. " has " .. payload_size .. " bytes");
      print("Closing file " .. file.file_name .. ". " .. file.file_bytes .. " bytes");
      file.open_fd:close();
      
      link.file = nil;
      link.state = filelink.IDLE_STATE;
      
    elseif(command == "fn") then
      if( link.state ~= filelink.IDLE_STATE ) then
        error(string.format("Unexpected command %s in state %s", command, link.state));
      end
      
      if( link.file ~= nil and link.file.open_fd ~= nil) then
        error("File still open " .. file.file_name);
      end
      
      local file = {file_name = nil, open_fd = nil, file_bytes = 0}
      
      file.file_name, err_msg = link.sock:receive(payload_size);
      if(file.file_name == nil) then
        error("Received nil: " .. err_msg);
      end
    
      print("Opening file " .. file.file_name);
      file.open_fd, err_msg = io.open(string.gsub(file.file_name, "\\", "\\\\"), "wb");
      
      if(file.open_fd == nil) then
        error("Can't open file, " .. file.file_name .. ": " .. err_msg);
      end
      
      link.file = file;
      link.state = filelink.RECV_FILE_STATE;
      
      return packet_size;
    end
    
    return header_size;
end

function filelink.send_file(link, source_file, dest_file)
  local fd, err_msg = io.open(source_file, "rb");
  if(fd == nil) then
    error("Can't open file " .. source_file .. ", error: " .. err_msg);
  end
  
  local header = string.format("fn %04d ", #dest_file);
  local packet = header .. dest_file;
  
  sock_lib.send_packet(link.sock, packet);
    
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
    
    link.sock:send(packet);
    
    if(next == nil) then
      break;
    end
    
    contents = next;
    next = fd:read(payload_size);
  end

  print(string.format("%s had %d bytes", source_file, file_bytes));
end

function filelink.send_file_list(link, dir, file_names)
  
  local header = string.format("fl %04d ", #dir);
  local packet = header .. dir;
  
  link.sock:send(packet);
  
  for file_name in files_names do
    local header = string.format("fl %04d ", #file_name);
    local packet = header .. dest_file;
    
    link.sock:send(packet);
  end
  
  header = "fd 0000 ";
  link.sock:send(header);
end

return filelink