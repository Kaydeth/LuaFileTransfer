local filelink = {}

local socket = require("socket");
local sock_lib = require("sock_lib");
local filesystem = require("filesystem");

filelink.SERVER = "server";
filelink.CLIENT = "client";

filelink.IDLE_STATE = "idle";
filelink.RECV_FILE_STATE = "file";
filelink.RECV_FILE_LIST_STATE = "filelist";
filelink.REQUEST_FILE_STATE = "reqfile";

local packet_size = 1024;  --bytes
local header_size = 8;  --bytes
local command_size = 3;   --bytes
local payload_size = packet_size - header_size;  --bytes

function filelink.create_link(link_type, local_addr, local_port, remote_addr, remote_port)
  local link = { sock = nil, state = nil, file = nil, dir = nil, file_list = nil};
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

local function file_done(link, command, payload_size, packet)
  local file = link.file;
    
  if( file == nil or file.open_fd == nil) then
    error("Unexpected fd command, file not open: " .. tostring(file.file_name));
  end

  --file done command will have the payload in the packet, payload will be nil
  payload = string.sub(packet, header_size + 1, header_size + payload_size);
  file.open_fd:write(payload);
  
  file.file_bytes = file.file_bytes + payload_size;      

  print("Last packet for " .. file.file_name .. " has " .. payload_size .. " bytes");
  print("Closing file " .. file.file_name .. ". " .. file.file_bytes .. " bytes");
  file.open_fd:close();
  
  link.file = nil;
  
  if(#link.file_list == 0) then
    link.dir = nil;
    link.state = filelink.IDLE_STATE;
  else
    filelink.send_file_request(link);
    link.state = filelink.REQUEST_FILE_STATE;
  end
end

local function file_list_done(link, command, payload_size, packet)
  
  if(#link.file_list == 0) then
    link.dir = nil;
    link.state = filelink.IDLE_STATE;
  else
    filelink.send_file_request(link);
    link.state = filelink.REQUEST_FILE_STATE;
  end
end

local function processCommand(link, command, payload_size, packet, payload)
    if(command == "py") then            
      if(link.state ~= filelink.RECV_FILE_STATE) then
        error(string.format("Unexpected command %s in state %s", command, link.state));
      end
      
      --file payload command will have the payload in the packet, payload will be nil
      payload = string.sub(packet, header_size + 1, header_size + payload_size);

      local file = link.file;
      file.open_fd:write(payload);
      
      file.file_bytes = file.file_bytes + payload_size;      
      
      return packet_size;
    elseif(command == "fd") then
      if(link.state == filelink.RECV_FILE_STATE) then
        file_done(link, command, payload_size, packet);
      elseif(link.state == filelink.RECV_FILE_LIST_STATE) then
        file_list_done(link, command, payload_size, packet);
      else
        error(string.format("Unexpected command %s in state %s", command, link.state));      
      end
    elseif( command == "fr") then
      if(link.state ~= filelink.IDLE_STATE) then
        error(string.format("Unexpected command %s in state %s", command, link.state));
      end
      
      local file_name = payload;
      filelink.send_file(link, link.dir .. file_name, file_name);
    elseif(command == "fn") then
      if( link.state ~= filelink.IDLE_STATE and link.state ~= filelink.REQUEST_FILE_STATE ) then
        error(string.format("Unexpected command %s in state %s", command, link.state));
      end
      
      if( link.file ~= nil and link.file.open_fd ~= nil) then
        error("Unexpected fn command. File still open " .. link.file.file_name);
      end
      
      local file = {file_name = nil, open_fd = nil, file_bytes = 0}
      
      if(link.state == filelink.REQUEST_FILE_STATE) then
        file.file_name = link.dir .. payload;
      else
        file.file_name = payload;
      end
      print("Opening file " .. file.file_name);
      file.open_fd, err_msg = io.open(string.gsub(file.file_name, "\\", "\\\\"), "wb");
      
      if(file.open_fd == nil) then
        error("Can't open file, " .. file.file_name .. ": " .. err_msg);
      end
      
      link.file = file;
      link.state = filelink.RECV_FILE_STATE;
      
      return packet_size;
    elseif(command == "fl") then
      if( link.state == filelink.IDLE_STATE ) then
        link.dir = payload;
        link.file_list = {};
        link.state = filelink.RECV_FILE_LIST_STATE;
        
        print("LSDEBUG: got dir " .. link.dir);
        
      elseif( link.state == filelink.RECV_FILE_LIST_STATE) then
        local file_name = payload;
        
        local abs_path = link.dir .. file_name;
        
        if( filesystem.fileExists(abs_path) == false ) then
          print("Need new file " .. file_name);
          table.insert(link.file_list, file_name);
        else
          print("LSDEBUG: file exists " .. file_name);
        end
      else
          error(string.format("Unexpected command %s in state %s", command, link.state));
      end
    end
    
    return header_size;
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
    local payload = nil;
    
    if(payload_size == nil) then
      error(string.format("Could not get payload size for command %s from string %s",
          command, tostring(payload_size_str)));
    end
    
    if(expected_bytes == header_size and payload_size ~= 0) then
      payload, err_msg = link.sock:receive(payload_size);
      if(payload == nil) then
        error("Received nil: " .. err_msg);
      end
    end

    expected_bytes = processCommand(link, command, payload_size, packet, payload);
  end
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

function filelink.send_file_list(link, source_dir, dest_dir, file_names)
  
  local header = string.format("fl %04d ", #dest_dir);
  local packet = header .. dest_dir;
  
  link.sock:send(packet);
    
  for file_name in file_names do
    local header = string.format("fl %04d ", #file_name);
    local packet = header .. file_name;
    
    print("LSDEBUG: sending fl: " .. file_name);
    
    link.sock:send(packet);
  end
  
  header = "fd 0000 ";
  link.sock:send(header);
  
  link.dir = source_dir;
end

function filelink.send_file_request(link)
  local file_name = table.remove(link.file_list);
  local packet = string.format("fr %04d %s", #file_name, file_name);
  
  link.sock:send(packet);
end

return filelink