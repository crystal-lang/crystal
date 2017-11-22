window.CrystalDoc = (window.CrystalDoc || {});

CrystalDoc.base_path = (CrystalDoc.base_path || "");

<%= JsSearchTemplate.new %>
<%= JsNavigatorTemplate.new %>
<%= JsUsageModal.new %>

document.addEventListener('DOMContentLoaded', function() {
  var sessionStorage;
  try {
    sessionStorage = window.sessionStorage;
  } catch (e) { }
  if(!sessionStorage) {
    sessionStorage = {
      setItem: function() {},
      getItem: function() {},
      removeItem: function() {}
    };
  }

  var repositoryName = document.getElementById('repository-name').getAttribute('content');
  var typesList = document.getElementById('types-list');
  var searchInput = document.getElementById('search-input');
  var parents = document.querySelectorAll('#types-list li.parent');

  var setPersistentSearchQuery = function(value){
    sessionStorage.setItem(repositoryName + '::search-input:value', value);
  }

  for(var i = 0; i < parents.length; i++) {
    var _parent = parents[i];
    _parent.addEventListener('click', function(e) {
      e.stopPropagation();

      if(e.target.tagName.toLowerCase() == 'li') {
        if(e.target.className.match(/open/)) {
          sessionStorage.removeItem(e.target.getAttribute('data-id'));
          e.target.className = e.target.className.replace(/ +open/g, '');
        } else {
          sessionStorage.setItem(e.target.getAttribute('data-id'), '1');
          if(e.target.className.indexOf('open') == -1) {
            e.target.className += ' open';
          }
        }
      }
    });

    if(sessionStorage.getItem(_parent.getAttribute('data-id')) == '1') {
      _parent.className += ' open';
    }
  }

  var leaveSearchScope = function(){
    CrystalDoc.toggleResultsList(false);
    window.focus();
  }

  var navigator = new Navigator(document.querySelector('#types-list'), searchInput, document.querySelector(".search-results"), leaveSearchScope);

  CrystalDoc.loadIndex();
  var searchTimeout;
  var lastSearchText = false;
  var performSearch = function() {
    document.dispatchEvent(new Event("CrystalDoc:searchDebounceStarted"));

    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(function() {
      var text = searchInput.value;

      if(text == "") {
        CrystalDoc.toggleResultsList(false);
      }else if(text == lastSearchText){
        document.dispatchEvent(new Event("CrystalDoc:searchDebounceStopped"));
      }else{
        CrystalDoc.search(text);
        navigator.highlightFirst();
        searchInput.focus();
      }
      lastSearchText = text;
      setPersistentSearchQuery(text);
    }, 200);
  };

  if(location.hash.length > 3 && location.hash.substring(0,3) == "#q="){
    // allows directly linking a search query which is then executed on the client
    // this comes handy for establishing a custom browser search engine with https://crystal-lang.org/api/#q=%s as a search URL
    // TODO: Add OpenSearch description
    var searchQuery = location.hash.substring(3);
    history.pushState({searchQuery: searchQuery}, "Search for " + searchQuery, location.href.replace(/#q=.*/, ""));
    searchInput.value = searchQuery;
    document.addEventListener('CrystalDoc:loaded', performSearch);
  }

  if (searchInput.value.length == 0) {
    var searchText = sessionStorage.getItem(repositoryName + '::search-input:value');
    if(searchText){
      searchInput.value = searchText;
    }
  }
  searchInput.addEventListener('keyup', performSearch);
  searchInput.addEventListener('input', performSearch);

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
        if(usageModal.isVisible()) {
          return;
        }
        event.stopPropagation();
        navigator.focus();
        performSearch();
        break;
    }
  }

  document.addEventListener('keyup', handleShortkeys);

  var scrollToEntryFromLocationHash = function() {
    var hash = window.location.hash;
    if (hash) {
      var targetAnchor = unescape(hash.substr(1));
      var targetEl = document.querySelectorAll('.entry-detail[id="' + targetAnchor + '"]');

      if (targetEl && targetEl.length > 0) {
        targetEl[0].offsetParent.scrollTop = targetEl[0].offsetTop;
      }
    }
  };
  window.addEventListener("hashchange", scrollToEntryFromLocationHash, false);
  scrollToEntryFromLocationHash();
});
