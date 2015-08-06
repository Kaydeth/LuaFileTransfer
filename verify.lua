local fs = require("filesystem");

local source = "C:\\MinGW\\include\\";
local dest = "c:\\luke\\LuaFileTransfer\\output\\";

local files = fs.listFiles(source);

--local rc, state, code = os.execute("fc /b " .. source .. "aclocal" .. " " .. dest .. "aclocal");
--print(string.format("RC = %s:%s:%s", tostring(rc), tostring(state), tostring(code)));

for file_name in files do
  local source_file = source .. file_name;
  local dest_file = dest .. file_name;
  
  local rc, state, code = os.execute("fc /b " .. source_file .. " " .. dest_file);
  
  if( rc == nil) then
    print(string.format("fc returned %s:%s:%s", tostring(rc), tostring(state), tostring(code)));
    error(file_name .. " is different");
  end
end
