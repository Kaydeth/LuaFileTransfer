local log = {}

local win_cmd = require("win_cmd");

local LOG_DIR = "logs\\"
local LOG_FILE = "file_transfer_log_%s_%s_%s.log";
local LOG_FD = nil;

function log.open_log()
  local year, month, day = win_cmd.get_parsed_date();
  
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
  local date = win_cmd.get_date();
  local time = win_cmd.get_time();
  
  LOG_FD:write(string.format("%s %s %s\n", date, time, message));
  LOG_FD:flush();
end

return log;