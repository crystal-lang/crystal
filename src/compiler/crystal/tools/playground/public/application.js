var defaultCode = 'a = 1\nb = 3\nc = a + b\nr = rand\nputs c + r\n';
var runDebounce = 300;

var ws = new WebSocket("ws://" + location.host + "/client");
var outputDom = document.getElementById('output');
var sidebarDom = $('#sidebar');
var consoleButton = $('a[href="#output-modal"]');
var runProgress = $('#run-progress');
var runTag = 0;

if(typeof(Storage) !== "undefined") {
  defaultCode = sessionStorage.lastCode || localStorage.lastCode || defaultCode;
}

var editor = CodeMirror(document.getElementById('editor'), {
  mode: 'crystal',
  theme: 'neat',
  lineNumbers: true,
  autofocus: true,
  tabSize: 2,
  viewportMargin: Infinity,
  value: defaultCode
});


var runTimeout = null;
function scheduleRun() {
  if (runTimeout != null) {
    clearTimeout(runTimeout);
  }
  runTimeout = window.setTimeout(run, runDebounce);
}

// when clicking below the editor, set the cursor at the very end
var editorDom = $('#editor').click(function(e){
  hideEditorErrors();
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
editor.on("change", function(){
  if(typeof(Storage) !== "undefined") {
    localStorage.lastCode = sessionStorage.lastCode = editor.getValue();
  }
  hideEditorErrors();
  matchEditorSidebarHeight();
  scheduleRun();
});
$(window).resize(matchEditorSidebarHeight);


var inspectModal = $("#inspect-modal");
var inspectModalTable = $(".inspect-table", inspectModal);
var inspectors = {};

function Inspector(line) {
  this.lineDom = $("<div>")
      .addClass("truncate")
      .css("top", editor.heightAtLine(line-1, "local") + "px")
      .css("cursor", "pointer");
  sidebarDom.append(this.lineDom);

  this.messages = [];

  this.lineDom.click(function() {
    var labels = this.dataLabels();
    inspectModalTable.empty();
    var tableHeaderRow = $("<tr>")
    inspectModalTable.append($("<thead>").append(tableHeaderRow));
    tableHeaderRow.append($("<th>").text("#"));
    for(var j = 0; j < labels.length; j++) {
      tableHeaderRow.append($("<th>").text(labels[j]));
    }
    tableHeaderRow.append($("<th>").text("Value"));

    var tableBody = $("<tbody>");
    inspectModalTable.append(tableBody);

    for(var i = 0; i < this.messages.length; i++) {
      var message = this.messages[i];
      var row = $("<tr>");
      row.append($("<td>").text(i+1));

      for(var j = 0; j < labels.length; j++) {
        row.append($("<td>").text(message.data[labels[j]]));
      }

      row.append($("<td>").text(message.value));
      tableBody.append(row);
    }
    inspectModal.openModal();
  }.bind(this));

  this.addMessage = function(message) {
    this.messages.push(message);
    if (this.messages.length == 1) {
      this.lineDom.text(message.value);
    } else {
      this.lineDom.text("(" + this.messages.length + " times)");
    }
  }.bind(this);

  this.dataLabels = function() {
    // collect all data labels, in order of apperance
    var res = []
    var resSet = {}
    for(var i = 0; i < this.messages.length; i++) {
      var message = this.messages[i];
      if (message.data) {
        for(var k in message.data) {
          if (resSet[k] != true) {
            resSet[k] = true;
            res.push(k);
          }
        }
      }
    }

    return res;
  }.bind(this);

  return this;
}

function clearInspectors() {
  sidebarDom.empty();
  inspectors = {};
}

function getInspector(line) {
  var res = inspectors[line];
  if (!res) {
    res = new Inspector(line);
    inspectors[line] = res;
  }
  return res;
}

var currentErrors = [];

function hideEditorErrors() {
  if (currentErrors != null) {
    for(var i = 0; i < currentErrors.length; i++) {
      currentErrors[i].clear();
    }
    currentErrors.splice(0,currentErrors.length);
    matchEditorSidebarHeight();
  }
}

function showEditorError(line, column, message, color) {
  var colorClass = "red" + (color > 0 ? " darken-" + Math.min(color, 4) : "");
  var cursor = $("<div>").addClass(colorClass + " editor-error-col");
  var dom = $("<div>")
    .append(cursor)
    .append($("<pre>")
      .addClass(colorClass + " editor-error-msg white-text")
      .text(message));
  currentErrors.push(editor.addLineWidget(line-1, dom[0]));
  cursor.css('left', column + 'ch');
  matchEditorSidebarHeight();
}

ws.onmessage = function(e) {
  var message = JSON.parse(e.data);
  if (message.tag != runTag) return; // discarding message form old execution

  switch (message.type) {
    case "run":
      break;
    case "output":
      outputDom.innerText = message.content;
      if (message.content.length > 0) {
        consoleButton.addClass('disabled');
        window.setTimeout(function(){
          consoleButton.removeClass('disabled');
        }, 200);
      }
      break;
    case "value":
      getInspector(message.line).addMessage(message);
      break;
    case "exit":
      runProgress.hide();
      break;
    case "exception":
      runProgress.hide();
      for (var i = 0; i < message.exception.length; i++) {
        var ex = message.exception[i];
        if (ex.file == "play" || ex.file == "") {
          showEditorError(ex.line, ex.column, ex.message, i);
        }
      }
      break;
    default:
      console.error("ws message not handled", message);
  }
};

function run() {
  runTag++;

  runProgress.show();
  clearInspectors();
  hideEditorErrors();
  outputDom.innerText = "";
  consoleButton.addClass('disabled');

  ws.send(JSON.stringify({
    type: "run",
    source: editor.getValue(),
    tag: runTag
  }));

  return false;
}

$(document).ready(function(){
  $('.modal-trigger').leanModal();

  scheduleRun();
});
