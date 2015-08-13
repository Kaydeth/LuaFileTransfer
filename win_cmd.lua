local win_cmd = {};

local time_cmd = "echo.|time";
function win_cmd.get_time()
  local time_str = win_cmd.get_cmd_output(time_cmd);
  
  time_str = string.match(time_str, "%d+:%d+:%d+.%d");
  
  return time_str;
end

local date_cmd = "date /t";
function win_cmd.get_date()
  local date_str = win_cmd.get_cmd_output(date_cmd);
  
  local month_day = string.match(date_str, "%d+/%d+");
  
  return month_day;
end

function win_cmd.get_parsed_date()
  local date_str = win_cmd.get_cmd_output(date_cmd);
  
  local iter = string.gmatch(date_str, "%d+");
  
  local month = iter();
  local day = iter();
  local year = iter();
  
  return year, month, day;
end

function win_cmd.get_cmd_output(cmd)
  local pipe, err_msg = io.popen(cmd, "r");
  
  if(pipe == nil) then
    error(string.format("Could not open pipe for command %s. Error: %s",
      tostring(cmd), tostring(err_msg)));
  end
  
  local output = pipe:read("*a");
  pipe:close();
  
  return output;
end

return win_cmd;