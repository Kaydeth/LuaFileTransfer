local log = {}

local LOG_DIR = "logs\\"
local LOG_FILE = "file_transfer_log_%s_%s_%s.log";
local LOG_FD = nil;

function log.open_log()
  local cmd = "date /t";
  local pipe, err_msg = io.popen(cmd, "r");
  
  if(pipe == nil) then
    error(string.format("Could not open pipe for command %s. Error: %s",
      tostring(cmd), tostring(err_msg)));
  end
  
  local output = pipe:read("*a");
  
  local iter = string.gmatch(output, "%d+");
  
  local month = iter();
  local day = iter();
  local year = iter();
  
  local file_name = string.format(LOG_FILE, year, month, day);
  local rel_path = LOG_DIR .. file_name;

  print("LSDEBUG: " .. file_name);
  
  local fd = nil;
  LOG_FD, err_msg = io.open(rel_path, "a");
  if( LOG_FD == nil) then
    error("Could not open log file: " .. rel_path .. ". Error: " .. tostring(err_msg));
  end
end

function log.close_log()
  io.close(LOG_FD);
end

function log.info(message)
  LOG_FD:write(message .. "\n");
  LOG_FD:flush();
end

return log;