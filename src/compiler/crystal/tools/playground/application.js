var ws = new WebSocket("ws://" + location.host);
var sourceDom = document.getElementById('source');
var outputDom = document.getElementById('output');
var sidebarDom = document.getElementById('sidebar');

ws.onmessage = function(e) {
  var message = JSON.parse(e.data);

  switch (message.type) {
    case "run":
      output.innerText = message.output;

      for(var i = 0; i < message.data.length; i++) {
        var data = message.data[i];
        var lineDom = document.createElement("div");

        var a = document.createAttribute("style");
        a.value = "top: " + (data.line-1) + "em;";
        lineDom.setAttributeNode(a);

        lineDom.appendChild(document.createTextNode(data.value));
        sidebarDom.appendChild(lineDom);
      }
      break;
    default:
      console.error("ws message not handled", message);
  }
};

function run() {
  while (sidebarDom.hasChildNodes()) {
    sidebarDom.removeChild(sidebarDom.childNodes[0]);
  }
  output.innerText = "";

  ws.send(JSON.stringify({
    type: "run",
    source: sourceDom.value
  }));
}
