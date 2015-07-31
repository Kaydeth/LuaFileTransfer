local socket = require("socket");
local fs = require("filesystem");

local local_addr = "localhost"
local local_port = "5555"
local remote_addr = "localhost"
local remote_port = "5556"

local source = "c:\\luke\\programs";
local dest = "c:\\luke\\LuaFileTransfer\\output";
