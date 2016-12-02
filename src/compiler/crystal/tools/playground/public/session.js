CodeMirror.keyMap.macDefault["Cmd-/"] = "toggleComment";
CodeMirror.keyMap.pcDefault["Ctrl-/"] = "toggleComment";

CodeMirror.keyMap.macDefault["Cmd-Enter"] = "runCode";
CodeMirror.keyMap.pcDefault["Ctrl-Enter"] = "runCode";

CodeMirror.commands.runCode = function(editor) {
  if (editor._playgroundSession) {
    editor._playgroundSession.run();
  }
};

function ModalDialog(options) {
  options = $.extend({}, {destroyOnClose: true}, options);

  $("body").append(
    this.modalDom = $("<div>").addClass("modal modal-fixed-footer")
      .append(this.modalContenDom = $("<div>").addClass("modal-content"))
      .append($("<div>").addClass("modal-footer")
        .append($("<a>").text("Close")
          .addClass("modal-action modal-close waves-effect waves-green btn-flat")
          .attr("href", "javascript:"))));

  this.onClose = function() { };

  this.openModal = function() {
    this.modalDom.openModal({
      complete: function() {
        this.onClose();
        if (options.destroyOnClose) {
          this.destroy();
        }
      }.bind(this)
    });
    return this;
  }.bind(this);

  this.append = function() {
    for(var i = 0; i < arguments.length; i++) {
      this.modalContenDom.append(arguments[i]);
    }
    return this;
  }.bind(this);

  this.destroy = function() {
    this.modalDom.remove();
  }.bind(this);

  return this;
}

function cdiv(cssClass) {
  return $("<div>").addClass(cssClass);
}

Playground.RunButtons = function(options) {
  var buildAnchor = function(tooltip, octicon) {
    return $("<a>").addClass("run-button btn-floating btn-large waves-effect waves-light tooltipped")
      .attr("href", "#")
      .attr("data-position", "left").attr("data-delay", "50").attr("data-tooltip", tooltip)
      .append($("<span>").addClass("mega-octicon " + octicon));
  }

  var buildProgress = function() {
    var buildSpinner = function(color) {
      return cdiv("spinner-layer spinner-" + color)
        .append(cdiv("circle-clipper left").append(cdiv("circle")))
        .append(cdiv("gap-patch").append(cdiv("circle")))
        .append(cdiv("circle-clipper right").append(cdiv("circle")))
    };

    return cdiv("preloader-wrapper big active run-button-preloader")
      .append(buildSpinner("blue"))
      .append(buildSpinner("red"))
      .append(buildSpinner("yellow"))
      .append(buildSpinner("green"));
  }

  var mac = /Mac/.test(navigator.platform);

  options.container
    .prepend(this.stopButton = buildAnchor("Stops code", "octicon-primitive-square"))
    .prepend(this.playButton = buildAnchor(mac ? "⌘ + Enter" : "Ctrl + Enter", "octicon-triangle-right"))
    .prepend(this.progress = buildProgress());

  this.stopButton.hide().tooltip();
  this.playButton.hide().tooltip();
  this.progress.hide();

  this.showPlay = function() {
    this.playButton.removeClass("disabled");
    this.playButton.show();
    this.stopButton.hide();
    this.progress.hide();
  }.bind(this);

  this.showStop = function() {
    this.playButton.removeClass("disabled");
    this.playButton.hide();
    this.stopButton.show();
    this.progress.show();
  }.bind(this);

  this.showPlayDisabled = function() {
    this.playButton.addClass("disabled");
    this.playButton.show();
    this.stopButton.hide();
    this.progress.hide();
  }.bind(this);

  this.onPlay = function() { }
  this.onStop = function() { }

  this.playButton.click(function(e) {
    e.preventDefault();
    this.onPlay();
  }.bind(this));

  this.stopButton.click(function(e) {
    e.preventDefault();
    this.onStop();
  }.bind(this));

  return this;
}

Playground.OutputIndicator = function(dom) {
  this.dom = dom;
  this.blinkTimeout = null;

  this.dom.append($("<span>").addClass("octicon octicon-terminal"));

  this.turnOnWithBlink = function () {
    this.dom.addClass('grey-text').removeClass('teal-text red-text');
    this.blinkTimeout = window.setTimeout(function(){
      if (this.isError) return;
      this.dom.removeClass('grey-text').addClass('teal-text');
    }.bind(this), 200);
  }.bind(this);

  this.turnOff = function () {
    this.isError = false;
    this._cancelBlink();
    this.dom.addClass('grey-text').removeClass('teal-text red-text');
  }.bind(this);

  this.turnError = function () {
    this.isError = true;
    this._cancelBlink();
    this.dom.addClass('red-text').removeClass('teal-text grey-text');
  }.bind(this);

  this._cancelBlink = function() {
    if (this.blinkTimeout != null) {
      clearTimeout(this.blinkTimeout);
    }
  }.bind(this);

  this.turnOff();

  return this;
}

Playground.Inspector = function(session, line) {
  this.lineDom = $("<div>")
      .addClass("truncate")
      .css("top", session.editor.heightAtLine(line-1, "local") + "px")
      .css("cursor", "pointer");
  session.sidebarDom.append(this.lineDom);

  var INSPECTOR_HOVER_CLASS = "inspector-hover";
  this.lineDom.hover(function(){
    session.editor.addLineClass(line-1, "wrap", INSPECTOR_HOVER_CLASS);
  }.bind(this), function(){
    session.editor.removeLineClass(line-1, "wrap", INSPECTOR_HOVER_CLASS);
  }.bind(this));

  this.messages = [];
  this.value_type = null; // null if mismatch. keep value if always the same.

  this.modal = null;

  var labels;
  var tableBody = null;
  var appendMessageToTableBody = function(i, message) {
    var row = $("<tr>");
    row.append($("<td>").text(i+1));

    for(var j = 0; j < labels.length; j++) {
      row.append($("<td>").text(message.data[labels[j]]));
    }

    row.append($("<td>").text(message.value));
    row.append($("<td>").text(message.value_type));
    tableBody.append(row);
  }

  this.lineDom.click(function() {
    var inspectModalTable = $("<table>").addClass("inspect-table highlight")

    labels = this.dataLabels();
    var tableHeaderRow = $("<tr>")
    inspectModalTable.append($("<thead>").append(tableHeaderRow));
    tableHeaderRow.append($("<th>").text("#"));
    for(var j = 0; j < labels.length; j++) {
      tableHeaderRow.append($("<th>").text(labels[j]));
    }
    tableHeaderRow.append($("<th>").text("Value"));
    tableHeaderRow.append($("<th>").text("Type"));

    tableBody = $("<tbody>");
    inspectModalTable.append(tableBody);

    for(var i = 0; i < this.messages.length; i++) {
      appendMessageToTableBody(i, this.messages[i]);
    }

    this.modal = new ModalDialog().append(inspectModalTable).openModal();
    this.modal.onClose = function() {
      this.modal = null;
    }.bind(this);
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
    if (this.value_type != null && Playground.settings.getShowTypes()) {
      this.lineDom.append($("<span>").addClass("type").text(this.value_type));
    }

    if (this.modal != null) {
      appendMessageToTableBody(this.messages.length-1, message);
    }
  }.bind(this);

  this.dataLabels = function() {
    // collect all data labels, in order of appearance
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

Playground.Session = function(options) {
  options = $.extend({}, {autofocus: false, source: ''}, options);

  // render components
  options.container.append(
    cdiv("col s7").append(
      this.editorWrapper = cdiv("card editor-wrapper")
        .append(cdiv("CodeMirror-gutters phantom"))
        .append(this.editorDom = cdiv("editor"))
      )
  ).append(
    cdiv("col s5").append(
      this.sidebarWrapper = cdiv("card card-plain sidebar-wrapper")
        .append(this.sidebarDom = cdiv("sidebar"))
      )
  );

  this.stdout = options.stdout;
  this.stdoutRawContent = "";
  this.outputIndicator = new Playground.OutputIndicator(options.outputIndicator);

  this.editor = CodeMirror(this.editorDom[0], {
    mode: 'crystal',
    theme: 'neat',
    lineNumbers: true,
    autofocus: options.autofocus,
    tabSize: 2,
    viewportMargin: Infinity,
    dragDrop: false, // dragDrop functionality is implemented to capture drop anywhere and replace source
    value: options.source
  });
  this.editor._playgroundSession = this;

  this.connect = function() {
    this.ws = new WebSocket("ws://" + location.host + "/client");

    this.ws.onopen = function() {
      this._triggerReady();
    }.bind(this);

    this.ws.onclose = function() {
      if (Playground.connectLostShown !== true) {
        Playground.connectLostShown = true;
        Materialize.toast('Connection lost. Refresh.');
      }
      this._triggerDisconnect();
    }.bind(this);

    this.ws.onmessage = function(e) {
      var message = JSON.parse(e.data);
      if (message.tag != this.runTag) return; // discarding message form old execution

      switch (message.type) {
        case "run":
          break;
        case "output":
          this._appendStdout(message.content);
          this.outputIndicator.turnOnWithBlink();
          break;
        case "value":
          this._getInspector(message.line).addMessage(message);
          break;
        case "runtime-exception":
          this._fullError = message.exception;
          var column =  this.editor.getLine(message.line-1).match(/\s*\S/)[0].length;
          this._showEditorError(message.line, column, message.exception, 0);
          break;
        case "exit":
          this._triggerFinish();

          if (message.status != 0) {
            this._appendStdout("\nexit status: " + message.status);
            this.outputIndicator.turnError();
          }
          break;
        case "exception":
          this._triggerFinish();

          var last_line = this.editor.lastLine() + 1;
          this._fullError = message.exception.message;
          if (message.exception.payload) {
            for (var i = 0; i < message.exception.payload.length; i++) {
              var ex = message.exception.payload[i];
              if (ex.file == "play" || ex.file == "") {
                // if there is an issue with the reported line,
                // let's make sure the error is displayed
                var ex_line = Math.min(ex.line, last_line);
                this._showEditorError(ex_line, ex.column, ex.message, i);
              }
            }
          } else {
            this._showEditorError(last_line, 1, "Compiler error", 0);
          }
          break;
        case "bug":
          this._triggerFinish();

          new ModalDialog().append(
            $("<h1>").append("Bug"),
            $("<p>")
              .append("You've reached a bug in the playground. Please ")
              .append($("<a>")
                .text("let us know")
                .attr("href", "https://github.com/crystal-lang/crystal/issues/new")
                .attr("target", "_blank"))
              .append(" about it."),
            $("<h2>").append("Code"),
            $("<pre>").append(this.editor.getValue()),
            $("<h2>").append("Exception"),
            $("<pre>").append(message.exception.message)).openModal();

          break;
        default:
          console.error("ws message not handled", message);
      }
    }.bind(this);
  }.bind(this);

  this.runTag = 0;
  this.run = function() {
    if (Playground.connectLostShown) return;

    this._removeScheduledRun();
    this.runTag++;

    this._clearInspectors();
    this._hideEditorErrors();
    this._clearStdout();

    this.ws.send(JSON.stringify({
      type: "run",
      source: this.editor.getValue(),
      tag: this.runTag
    }));

    this._triggerRun();
  }.bind(this);

  this.stop = function() {
    this.ws.send(JSON.stringify({
      type: "stop",
      tag: this.runTag
    }));
  }.bind(this);

  this.getSource = function() {
    return this.editor.getValue();
  }.bind(this);

  this.setSource = function(value) {
    this.editor.setValue(value);
  }.bind(this);

  this.bindRunButtons = function(runButtons, options) {
    options = $.extend({}, {autorun: false}, options);
    runButtons.showPlayDisabled();

    this.onReady = function() {
      runButtons.showPlay();
      if (options.autorun) {
        this.run();
      }
    }.bind(this);

    this.onRun = function() {
      runButtons.showStop();
    }.bind(this);

    this.onFinish = function() {
      runButtons.showPlay();
    }.bind(this);

    this.onDisconnect = function() {
      runButtons.showPlayDisabled();
    }.bind(this);

    runButtons.onPlay = function() {
      this.run();
    }.bind(this);

    runButtons.onStop = function() {
      this.stop();
    }.bind(this);
  }.bind(this);

  this.onReady = function() { };
  this.onRun = function() { };
  this.onFinish = function() { };
  this.onDisconnect = function() { };
  this.onChange = function() { };

  this._triggerReady = function() { this.onReady(this); }.bind(this);
  this._triggerRun = function() { this.onRun(this); }.bind(this);
  this._triggerFinish = function() { this.onFinish(this); }.bind(this);
  this._triggerDisconnect = function() { this.onDisconnect(this); }.bind(this);
  this._triggerChange = function() { this.onChange(this); }.bind(this);

  // schedule run
  this._runTimeout = null;

  this._removeScheduledRun = function() {
    if (this._runTimeout == null) return;
    clearTimeout(this._runTimeout);
  }.bind(this);

  this._scheduleRun = function() {
    this._removeScheduledRun();
    if (isFinite(Playground.settings.getRunDebounce())) {
      this._runTimeout = window.setTimeout(function(){
        this.run();
      }.bind(this), Playground.settings.getRunDebounce());
    }
  }.bind(this);
  //

  // editor errors
  var renderConsoleText = function(dom, text) {
    var lines = text.match(/[^\r\n]+/g);

    for(var i = 0; i < lines.length; i++) {
      if (i > 0) {
        dom.append("<br>");
      }
      var str = lines[i];
      var firstNonWhite = 0;
      while (str[firstNonWhite] == ' ') {
        firstNonWhite++;
      }
      var rendered = "\u00a0".repeat(firstNonWhite) + str.substring(firstNonWhite);
      dom.append(document.createTextNode(rendered));
    }

    return dom;
  };

  this.currentErrors = [];

  this._hideEditorErrors = function() {
    this._fullError = null;
    for(var i = 0; i < this.currentErrors.length; i++) {
      this.currentErrors[i].clear();
    }
    this.currentErrors.splice(0,this.currentErrors.length);
    this._matchEditorSidebarHeight();
  }.bind(this);

  this._showEditorError = function(line, column, message, color) {
    var msg;
    var colorClass = "red" + (color > 0 ? " darken-" + Math.min(color, 4) : "");
    var cursor = $("<div>").addClass(colorClass + " editor-error-col");
    var dom = $("<div>").addClass("editor-error")
      .append(cursor)
      .append(renderConsoleText($("<div>"), message)
        .addClass(colorClass + " editor-error-msg white-text"));

    this.currentErrors.push(this.editor.addLineWidget(line-1, dom[0]));
    cursor.css('left', column + 'ch');
    this._matchEditorSidebarHeight();
    dom.click(function(e) {
      this._showFullError();
      e.stopPropagation();
    }.bind(this));
  }.bind(this);

  this._showFullError = function() {
    new ModalDialog().append(
      $("<h1>").append("Error"),
      $("<pre>").css("min-height", "70%").text(this._fullError))
      .openModal();
  }.bind(this);
  //

  // inspectors
  this.inspectors = {};
  this._clearInspectors = function() {
    this.sidebarDom.empty();
    this.inspectors = {};
  }.bind(this);

  this._getInspector = function(line) {
    var res = this.inspectors[line];
    if (!res) {
      res = new Playground.Inspector(this, line);
      this.inspectors[line] = res;
    }
    return res;
  }.bind(this);
  //

  //stdout
  this._appendStdout = function(content) {
    this.stdoutRawContent += content;
    this.stdout[0].innerHTML = ansi_up.ansi_to_html(ansi_up.escape_for_html(this.stdoutRawContent), {"use_classes": true});
  }.bind(this);

  this._clearStdout = function() {
    this.stdoutRawContent = "";
    this.stdout[0].innerHTML = "";
    this.outputIndicator.turnOff();
  }.bind(this);
  //

  this._matchEditorSidebarHeight = function() {
    window.setTimeout(function(){
      this.sidebarWrapper.height(this.editorWrapper.height());
    }.bind(this),0)
  }.bind(this);

  this.editor.on("change", function(){
    this._triggerChange(); // -> saveAsLastCode();
    this._hideEditorErrors();
    this._matchEditorSidebarHeight();
    this._scheduleRun();
  }.bind(this));

  // when clicking below the editor, set the cursor at the very end
  this.editorDom.click(function(e){
    this._hideEditorErrors();
    if (e.target == this.editorDom[0]) {
      var info = this.editor.lineInfo(this.editor.lastLine())
      this.editor.setCursor(info.line, info.text.length);
      this.editor.focus();
    }
  }.bind(this));

  $(window).resize(this._matchEditorSidebarHeight);
  this._matchEditorSidebarHeight();

  $(window).unload(function(){
    this.stop();
  }.bind(this));
};
