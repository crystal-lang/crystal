window.CrystalDocs = (window.CrystalDocs || {});

CrystalDocs.base_path = (CrystalDocs.base_path || "");

<%= JsUsageModal.new %>

document.addEventListener('DOMContentLoaded', function() {
  var usageModal = new UsageModal('Keyboard Shortcuts', '' +
      '<ul class="usage-list">' +
      '  <li>' +
      '    <span class="usage-key">' +
      '      <kbd>s</kbd>,' +
      '      <kbd>/</kbd>' +
      '    </span>' +
      '    Search' +
      '  </li>' +
      '  <li>' +
      '    <kbd class="usage-key">Esc</kbd>' +
      '    Abort search / Close modal' +
      '  </li>' +
      '  <li>' +
      '    <span class="usage-key">' +
      '      <kbd>⇨</kbd>,' +
      '      <kbd>Enter</kbd>' +
      '    </span>' +
      '    Open highlighted result' +
      '  </li>' +
      '  <li>' +
      '    <span class="usage-key">' +
      '      <kbd>⇧</kbd>,' +
      '      <kbd>Ctrl+j</kbd>' +
      '    </span>' +
      '    Select previous result' +
      '  </li>' +
      '  <li>' +
      '    <span class="usage-key">' +
      '      <kbd>⇩</kbd>,' +
      '      <kbd>Ctrl+k</kbd>' +
      '    </span>' +
      '    Select next result' +
      '  </li>' +
      '  <li>' +
      '    <kbd class="usage-key">?</kbd>' +
      '    Show usage info' +
      '  </li>' +
      '</ul>'
    );
    function searchAction() {
      if(usageModal.isVisible()) {
        return;
      }
      sidebarIframe.contentWindow.postMessage({action: "performSearch"}, "*")
    }

    window.addEventListener("message", function(event) {
      switch(event.data.action) {
        case "showUsageModal":
          usageModal.show();
          break;
        case "escape":
          usageModal.hide();
          break;
        case "search":
          searchAction();
          break;
      }
    })

    function handleShortkeys(event) {
      var element = event.target || event.srcElement;

      if(element.tagName == "INPUT" || element.tagName == "TEXTAREA" || element.parentElement.tagName == "TEXTAREA"){
        return;
      }

      switch(event.key) {
        case "?":
          usageModal.show();
          break;

        case "Escape":
          usageModal.hide();
          break;

        case "s":
        case "/":
          event.stopPropagation();
          searchAction()
          break;
      }
    }

  document.addEventListener('keyup', handleShortkeys);

  var scrollToEntryFromLocationHash = function() {
    var hash = window.location.hash;
    if (hash) {
      var targetAnchor = decodeURI(hash.substr(1));
      var targetEl = document.getElementById(targetAnchor)
      if (targetEl) {
        targetEl.offsetParent.scrollTop = targetEl.offsetTop;
      }
    }
  };
  window.addEventListener("hashchange", scrollToEntryFromLocationHash, false);
  scrollToEntryFromLocationHash();

  var sidebarIframe = document.querySelector(".sidebar")
  sidebarIframe.addEventListener("load", function(){
    sidebarIframe.contentWindow.postMessage({
      action: "initType",
      url: window.location.href,
      isWideViewport: !(window.matchMedia('only screen and (max-width: 635px)')).matches
    }, "*")
  });

});
