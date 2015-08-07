local filelink = require("filelink");
local fs = require("filesystem");
local sl = require("sock_lib");

local local_addr = "localhost"
local local_port = "15000"
local remote_addr = "localhost"
local remote_port = "16000"

local source = "c:\\luke\\LuaFileTransfer\\input\\";
local dest = "c:\\luke\\LuaFileTransfer\\output\\";


local files = fs.listFiles(source);

local link = filelink.create_link(filelink.CLIENT, nil, nil, remote_addr, remote_port);


filelink.send_file_list(link, source, dest, files);

--Wait for file requests from other side
filelink.command_loop(link);

--[[
for file_name in files do
  filelink.send_file(link, source .. file_name, dest .. file_name);
end
]]
