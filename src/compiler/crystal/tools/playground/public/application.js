var ws = new WebSocket("ws://" + location.host);
var outputDom = document.getElementById('output');
var sidebarDom = document.getElementById('sidebar');
var consoleButton = $('a[href="#output-modal"]')

var editor = CodeMirror(document.getElementById('editor'), {
  mode: 'crystal',
  theme: 'neat',
  lineNumbers: true,
  autofocus: true,
  tabSize: 2,
  viewportMargin: Infinity,
  value: 'a = 1\nb = 3\nc = a + b\nr = rand\nputs c + r\n'
});


// when clicking below the editor, set the cursor at the very end
var editorDom = $('#editor').click(function(e){
  if (e.target == editorDom[0]) {
    var info = editor.lineInfo(editor.lastLine())
    editor.setCursor(info.line, info.text.length);
    editor.focus();
  }
});

var sidebarWrapper = $('#sidebar-wrapper');
var editorWrapper = $('#editor-wrapper');
var matchEditorSidebarHeight = function() {
  window.setTimeout(function(){
    sidebarWrapper.height(editorWrapper.height());
  },0)
};
editor.on("change", matchEditorSidebarHeight);
$(window).resize(matchEditorSidebarHeight);


ws.onmessage = function(e) {
  var message = JSON.parse(e.data);

  switch (message.type) {
    case "run":
      outputDom.innerText = message.output;
      if (message.output.length > 0) {
        consoleButton.removeClass('disabled');
      }
      break;
    case "value":
      var lineDom = $("<div>")
      lineDom.addClass("truncate")
      lineDom.css("top", ((message.line-1) * 1.46 + 0.5)+ "em");
      lineDom.text(message.value);
      sidebarDom.appendChild(lineDom[0]);
      break;
    default:
      console.error("ws message not handled", message);
  }
};

function run() {
  while (sidebarDom.hasChildNodes()) {
    sidebarDom.removeChild(sidebarDom.childNodes[0]);
  }
  outputDom.innerText = "";
  consoleButton.addClass('disabled');

  ws.send(JSON.stringify({
    type: "run",
    source: editor.getValue()
  }));

  return false;
}

$(document).ready(function(){
  $('.modal-trigger').leanModal();
});
