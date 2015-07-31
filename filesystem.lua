local filesystem = {}

function filesystem.listContents(path, option)
  local cmd = "dir /B";
  
  if(option ~= nil) then
    cmd = cmd .. " " .. option;
  end
  
  if(path ~= nil) then
    cmd = cmd .. " " .. path;
  end
 
  --local rc, err_msg, status_code = os.execute(cmd .. " > NUL");
  
  --if( rc == nil or status_code ~= 0) then
   -- print("Command " .. cmd .. " failed: " .. tostring(rc) .. ":" .. err_msg .. ":" .. tostring(status_code));
    --return nil;
  --end
  
  local pipe;
  pipe = io.popen(cmd, "r");
    
  if( pipe == nil ) then
    print("Failed to pipe command: " .. cmd);
    return nil;
  end
  
  return pipe:lines();
end

function filesystem.listFiles(path)
  return filesystem.listContents(path, "/A-D");
end

function filesystem.listDirectories(path)
  return filesystem.listContents(path, "/AD");
end

return filesystem