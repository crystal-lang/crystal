window.CrystalDocs = (window.CrystalDocs || {});

CrystalDocs.base_path = (CrystalDocs.base_path || "");

<%= JsSearchTemplate.new %>
<%= JsNavigatorTemplate.new %>
<%= JsVersionsTemplate.new %>

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

  var repositoryName = document.querySelector('[name=repository-name]').getAttribute('content');
  var typesList = document.querySelector('.types-list');
  var searchInput = document.querySelector('.search-input');
  var parents = document.querySelectorAll('.types-list li.parent');

  var scrollSidebarToOpenType = function(url, isWideViewport){
    var sidebarPath = window.location.pathname;
    var currentPath = new URL(url).pathname.substring(sidebarPath.length - "sidebar.html".length);

    var link = typesList.querySelector(`a[href="${currentPath}"]`);
    if(link) {
      link.parentNode.classList.add("current");

      traverseUpwards(link, typesList, function(node) {
        if(node.tagName == "LI") {
          node.classList.add("open")
        }
      });

      link.scrollIntoView(isWideViewport);
    }
  }

  function traverseUpwards(start, end, callback) {
    var root = start.getRootNode();
    start = start.parentElement;
    while(start != end && start != root) {
      callback(start)
      start = start.parentElement;
    }
  }

  window.addEventListener("message", function(event) {
    switch(event.data.action) {
      case "performSearch":
        navigator.focus();
        performSearch();
        break;
      case "initType":
        url = event.data.url
        scrollSidebarToOpenType(url, event.isWideViewport);
        searchFromUrl(new URL(url));
        break;
    }
  });

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
    CrystalDocs.toggleResultsList(false);
    window.focus();
  }

  var navigator = new Navigator(document.querySelector('.types-list'), searchInput, document.querySelector(".search-results"), leaveSearchScope);

  CrystalDocs.loadIndex();
  var searchTimeout;
  var lastSearchText = false;
  var performSearch = function() {
    document.dispatchEvent(new Event("CrystalDocs:searchDebounceStarted"));

    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(function() {
      var text = searchInput.value;

      if(text == "") {
        CrystalDocs.toggleResultsList(false);
      }else if(text == lastSearchText){
        document.dispatchEvent(new Event("CrystalDocs:searchDebounceStopped"));
      }else{
        CrystalDocs.search(text);
        navigator.highlightFirst();
        searchInput.focus();
      }
      lastSearchText = text;
      setPersistentSearchQuery(text);
    }, 200);
  };

  function searchFromUrl(url) {
    if(url.hash.length > 3 && url.hash.substring(0,3) == "#q="){
      // allows directly linking a search query which is then executed on the client
      // this comes handy for establishing a custom browser search engine with https://crystal-lang.org/api/#q=%s as a search URL
      // TODO: Add OpenSearch description
      var searchQuery = url.hash.substring(3);
      history.pushState({searchQuery: searchQuery}, "Search for " + searchQuery, url.href.replace(/#q=.*/, ""));
      searchInput.value = decodeURIComponent(searchQuery);
      document.addEventListener('CrystalDocs:loaded', performSearch);
    }

    if (searchInput.value.length == 0) {
      var searchText = sessionStorage.getItem(repositoryName + '::search-input:value');
      if(searchText){
        searchInput.value = searchText;
      }
    }
  }
  searchInput.addEventListener('keyup', performSearch);
  searchInput.addEventListener('input', performSearch);

  function handleShortkeys(event) {
    var element = event.target || event.srcElement;

    if(element.tagName == "INPUT" || element.tagName == "TEXTAREA" || element.parentElement.tagName == "TEXTAREA"){
      return;
    }

    switch(event.key) {
      case "?":
        window.parent.postMessage({action: "showUsageModal"}, "*")
        break;

      case "Escape":
        window.parent.postMessage({action: "escape"}, "*")
        break;

      case "s":
      case "/":
        window.parent.postMessage({action: "search"}, "*")
        break;
    }
  }

  document.addEventListener('keyup', handleShortkeys);
});
