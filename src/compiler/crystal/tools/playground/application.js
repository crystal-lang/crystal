var ws = new WebSocket("ws://" + location.host);
var sourceDom = document.getElementById('source');
var outputDom = document.getElementById('output');

ws.onmessage = function(e) {
  var message = JSON.parse(e.data);

  switch (message.type) {
    case "run":
      output.innerText = message.output;
      break;
    default:
      console.error("ws message not handled", message);
  }
};

function run() {
  ws.send(JSON.stringify({
    type: "run",
    source: sourceDom.value
  }));
}
