local sock_lib = {}

function sock_lib.send_packet(socket, packet)
  local sent_bytes = 0;
  local bytes_to_send = #packet;
  while(sent_bytes < bytes_to_send) do
    local bytes, err_msg = socket:send(packet);
    
    if(bytes == nil or bytes == 0) then
      error("Send failed, bytes = " .. tostring(bytes) .. ", error: " .. err_msg);
    end
    
    sent_bytes = sent_bytes + bytes;
  end
end

return sock_lib;