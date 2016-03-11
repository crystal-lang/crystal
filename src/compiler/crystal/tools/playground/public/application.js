var ws = new WebSocket("ws://" + location.host);
var outputDom = document.getElementById('output');
var sidebarDom = document.getElementById('sidebar');
var sidebarWitnessDom = document.getElementById('witness');

var editor = CodeMirror(document.getElementById('editor'), {
  mode: 'crystal',
  theme: 'neat',
  lineNumbers: true,
  autofocus: true,
  tabSize: 2,
  value: 'a = 1\nb = 3\nc = a + b\nr = rand\nputs c + r\n'
});

editor.on("scroll", function(){
  var scrollInfo = editor.getScrollInfo()
  sidebarWitnessDom.style.height = scrollInfo.height + 'px';
  sidebarDom.scrollTop = scrollInfo.top;
});

ws.onmessage = function(e) {
  var message = JSON.parse(e.data);

  switch (message.type) {
    case "run":
      output.innerText = message.output;
      break;
    case "value":
      var lineDom = document.createElement("div");

      var a = document.createAttribute("style");
      a.value = "top: " + ((message.line-1) * 15 + 4)+ "px;";
      lineDom.setAttributeNode(a);

      lineDom.appendChild(document.createTextNode(message.value));
      sidebarDom.appendChild(lineDom);
      break;
    default:
      console.error("ws message not handled", message);
  }
};

function run() {
  sidebarDom.removeChild(sidebarWitnessDom);
  while (sidebarDom.hasChildNodes()) {
    sidebarDom.removeChild(sidebarDom.childNodes[0]);
  }
  sidebarDom.appendChild(sidebarWitnessDom);
  output.innerText = "";

  ws.send(JSON.stringify({
    type: "run",
    source: editor.getValue()
  }));
}
