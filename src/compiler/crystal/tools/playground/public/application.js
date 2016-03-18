$(function(){
  $('.modal-trigger').leanModal();
});

var defaultCode = 'a = 1\nb = 3\nc = a + b\nr = rand\nputs c + r\n';

if (Playground.hasStorage) {
  defaultCode = sessionStorage.lastCode || localStorage.lastCode || defaultCode;
}

// main page initialization
$(function(){
  if ($('#mainEditorContainer').length == 0)
    return;

  var session = new Playground.Session({
    container: $('#mainEditorContainer'),
    stdout: $('#mainOutput'),
    outputIndicator: $('#mainOutputIndicator'),
    source: defaultCode,
    autofocus: true,
  });
  var buttons = new Playground.RunButtons({
    container: $('#mainButtonsContainer')
  });
  session.bindRunButtons(buttons, {autorun: true});
  session.connect();

  function saveAsLastCode() {
    if(typeof(Storage) !== "undefined") {
      localStorage.lastCode = sessionStorage.lastCode = session.getSource();
    }
  }
  session.onChange = function() {
    saveAsLastCode();
  };
  window.onunload = function(){
    saveAsLastCode();
  };

  $("#saveAsFile").click(function(e) {
    var uri = "data:text/plain;charset=utf-8," + encodeURIComponent(session.getSource());

    var link = $("<a>");
    $("body").append(link);
    link.attr('download', 'play.cr');
    link.attr('href', uri);
    link[0].click();
    link.remove();

    e.preventDefault();
  });

  $("#saveAsGist").click(function(e) {
    if (Playground.settings.getGithubToken() == '') {
      window.open('/settings.html');
      return;
    }

    $.ajax({
      type:"POST",
      beforeSend: function (request) {
        request.setRequestHeader("Authorization", "token " + Playground.settings.getGithubToken());
      },
      url: "https://api.github.com/gists",
      data: JSON.stringify({
        "public": true,
        "files": {"play.cr": {"content": session.getSource() }}
      }),
      success: function(msg) {
        new ModalDialog().append(
          $("<p>")
            .append("There is a new gist at ")
            .append($("<a>")
              .attr("href", msg.html_url)
              .attr("target", "_blank")
              .append($("<span>").text(msg.html_url))
              .append(" ")
              .append($("<span>").addClass("octicon octicon-link-external"))
            )).openModal();
      }
    });
    Materialize.toast('Uploading gist', 4000);

    e.preventDefault();
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
        session.setSource(reader.result);
      };
      reader.readAsText(files[0]);
    }
    return false;
  };

  $(window).resize(session._matchEditorSidebarHeight());
});


// about page initialization
function initDemoPlayground(dom) {
  var editorContainer, output, outputIndicator, buttonsContainer;

  dom.after(editorContainer = $("<div>").addClass("row row-narrow"));
  editorContainer.after(
    $("<div>").addClass("row").append(
      $("<div>").addClass("col s7").append(
        $("<div>").addClass("card card-plain").append(
          output = $("<pre>").addClass("output").css("min-height", "1.5em")))
      ).append(
      outputIndicator = $("<div>").addClass("col s1")
      ).append(
        $("<div>").addClass("col s4").append(buttonsContainer = $("<div>").addClass("demoButtonsContainer"))
      ));

  var session = new Playground.Session({
    container: editorContainer,
    stdout: output,
    outputIndicator: outputIndicator,
    source: dom.text()
  });
  dom.remove();
  var buttons = new Playground.RunButtons({
    container: buttonsContainer
  });
  session.bindRunButtons(buttons);
  session.connect();
}

$(function(){
  $(".playground").each(function(){
    initDemoPlayground($(this));
  });
});
