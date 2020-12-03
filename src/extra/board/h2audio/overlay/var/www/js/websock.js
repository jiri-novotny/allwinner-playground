if ("WebSocket" in window)
{
  //alert("WebSocket is supported by your Browser!");

  // Let us open a web socket
  var ws = new WebSocket("ws://" + window.location.hostname + ":8080");

  ws.onopen = function()
  {
    // Web Socket is connected, send data using send()
    ws.send("init");
  };

  ws.onmessage = function (evt) 
  { 
    var resp = evt.data.split(";");
    
    for (i = 0; i < resp.length; i++)
    { 
      var node = resp[i].split("=");
      if (node.length > 1)
      {
        document.getElementById(node[0]).innerHTML = node[1];
      }
    }
  };

  ws.onclose = function()
  { 
    // websocket is closed.
    alert("WS connection closed!"); 
  };
  
  window.onbeforeunload = function() {
    websocket.onclose = function () {}; // disable onclose handler first
    websocket.close()
  };
}  
else
{
  // The browser doesn't support WebSocket
  alert("WebSocket NOT supported by your Browser!");
}
