var defaultCode = 'a = 1\nb = 3\nc = a + b\nr = rand\nputs c + r\n';
var runDebounce = 300;

var ws = new WebSocket("ws://" + location.host + "/client");
var outputDom = document.getElementById('output');
var sidebarDom = $('#sidebar');
var consoleButton = $('a[href="#output-modal"]');
var runButton = $('#run');
var runProgress = $('#run-progress');
var runTag = 0;

// begin Settings
// default settings
if(typeof(localStorage.settingsGithubToken) === 'undefined') {
  localStorage.settingsGithubToken = ''
}
if(typeof(localStorage.settingsShowTypes) === 'undefined') {
  localStorage.settingsShowTypes = 'true'
}
$(document).ready(function(){
  function loadSettings() {
    $("[name=settingsGithubToken]").val(localStorage.settingsGithubToken);
    $("[name=settingsShowTypes]").prop('checked', localStorage.settingsShowTypes == 'true');
  }

  loadSettings();

  $('[href="#settings-modal"]').leanModal({
    ready: loadSettings,
    complete: function() {
      localStorage.settingsGithubToken = $("[name=settingsGithubToken]").val();
      localStorage.settingsShowTypes = $("[name=settingsShowTypes]").is(":checked") ? 'true' : 'false';
    }
  })
})
// end Settings


if(typeof(Storage) !== "undefined") {
  defaultCode = sessionStorage.lastCode || localStorage.lastCode || defaultCode;
}

CodeMirror.keyMap.macDefault["Cmd-/"] = "toggleComment";
CodeMirror.keyMap.pcDefault["Ctrl-/"] = "toggleComment";

CodeMirror.keyMap.macDefault["Cmd-Enter"] = "runCode";
CodeMirror.keyMap.pcDefault["Ctrl-Enter"] = "runCode";

CodeMirror.commands.runCode = function() {
  run();
}

var editor = CodeMirror(document.getElementById('editor'), {
  mode: 'crystal',
  theme: 'neat',
  lineNumbers: true,
  autofocus: true,
  tabSize: 2,
  viewportMargin: Infinity,
  dragDrop: false, // dragDrop functionality is implemented to capture drop anywhere and replace source
  value: defaultCode
});


var runTimeout = null;
function removeScheduledRun() {
  if (runTimeout == null) return;
  clearTimeout(runTimeout);
}
function scheduleRun() {
  removeScheduledRun()
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


var fixedModal = $("#fixed-modal");

function showModal() {
  var content = $(".modal-content", fixedModal).empty();
  for(var i = 0; i < arguments.length; i++) {
    content.append(arguments[i]);
  }
  fixedModal.openModal();
}

var inspectors = {};

function Inspector(line) {
  var inspectModalTable = $("<table>").addClass("inspect-table highlight")

  this.lineDom = $("<div>")
      .addClass("truncate")
      .css("top", editor.heightAtLine(line-1, "local") + "px")
      .css("cursor", "pointer");
  sidebarDom.append(this.lineDom);

  this.messages = [];
  this.value_type = null; // null if mismatch. keep value is always the same.

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
    tableHeaderRow.append($("<th>").text("Type"));

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
      row.append($("<td>").text(message.value_type));
      tableBody.append(row);
    }
    showModal(inspectModalTable);
  }.bind(this));

  this.addMessage = function(message) {
    this.messages.push(message);
    if (this.messages.length == 1) {
      this.lineDom.text(message.value);
      this.value_type = message.value_type;
    } else {
      this.lineDom.text("(" + this.messages.length + " times)");
      if (this.value_type != message.value_type) {
        this.value_type = null;
      }
    }
    if (this.value_type != null && localStorage.settingsShowTypes == 'true') {
      this.lineDom.append($("<span>").addClass("type").text(this.value_type));
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

ws.onclose = function() {
  runButton.addClass("disabled");
  runProgress.hide();
  Materialize.toast('Connection lost. Refresh.');
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
        consoleButton.addClass('grey-text').removeClass('teal-text');
        window.setTimeout(function(){
          consoleButton.removeClass('grey-text').addClass('teal-text');
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
      for (var i = 0; i < message.exception.payload.length; i++) {
        var ex = message.exception.payload[i];
        if (ex.file == "play" || ex.file == "") {
          showEditorError(ex.line, ex.column, ex.message, i);
        }
      }
      break;
    case "bug":
      runProgress.hide();
      showModal(
        $("<h4>").append("Bug"),
        $("<p>")
          .append("You've reached a bug in the playground. Please ")
          .append($("<a>")
            .text("let us know")
            .attr("href", "https://github.com/crystal-lang/crystal/issues/new")
            .attr("target", "_blank"))
          .append(" about it."),
        $("<h5>").append("Code"),
        $("<pre>").append(editor.getValue()),
        $("<h5>").append("Exception"),
        $("<pre>").append(message.exception.message));
    default:
      console.error("ws message not handled", message);
  }
};

function run() {
  removeScheduledRun();
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

function saveAsFile() {
  var uri = "data:text/plain;charset=utf-8," + encodeURIComponent(editor.getValue());

  var link = $("<a>");
  $("body").append(link);
  link.attr('download', 'play.cr');
  link.attr('href', uri);
  link[0].click();
  link.remove();

  return false;
}

function saveAsGist() {
  if (localStorage.settingsGithubToken == '') {
    $('[href="#settings-modal"]').click();
  }

  $.ajax({
    type:"POST",
    beforeSend: function (request) {
      request.setRequestHeader("Authorization", "token " + localStorage.settingsGithubToken);
    },
    url: "https://api.github.com/gists",
    data: JSON.stringify({
      "public": true,
      "files": {"play.cr": {"content": editor.getValue() }}
    }),
    success: function(msg) {
      showModal(
        $("<p>")
          .append("There is a new gist at ")
          .append($("<a>")
            .attr("href", msg.html_url)
            .attr("target", "_blank")
            .append($("<span>").text(msg.html_url))
            .append(" ")
            .append($("<span>").addClass("octicon octicon-link-external"))
          ));
    }
  });

  return false;
}

$(document).ready(function(){
  $('.modal-trigger').leanModal();

  scheduleRun();

  var mac = /Mac/.test(navigator.platform);
  runButton.attr('data-tooltip', mac ? '⌘ + Enter' : 'Ctrl + Enter');
});

// load file by drag and drop
var doc = document.documentElement;
doc.ondragover = function () { return false; };
doc.ondragend = function () { return false; };
doc.ondrop = function (event) {
  event.preventDefault && event.preventDefault();
  var files = event.dataTransfer.files;
  if (files.length > 0) {
    var reader = new FileReader();
    reader.onload = function (event) {
      editor.setValue(reader.result);
    };
    reader.readAsText(files[0]);
  }
  return false;
};
