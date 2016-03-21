document.addEventListener('DOMContentLoaded', function() {
  var sessionStorage = window.sessionStorage;
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
  var typesLinks = document.querySelectorAll('#types-list li a');
  var query = function queryParams() {
    var str = window.location.search;
    var params = {};
    str.replace(
      new RegExp('([^?=&]+)=([^&]*)', 'g'),
      function($0, $1, $2) { params[$1] = $2; }
    );
    return params;
  }()['q'] || '';

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
  };

  for (var i = 0; i < typesLinks.length; i ++) {
    typesLinks[i].addEventListener("click", function(e) {
      if (query) {
        e.preventDefault();
        window.location.href = this.href + '?q=' + query;
      }
    }, false);
  }

  var childMatch = function(type, regexp){
    var types = type.querySelectorAll("ul li");
    for (var j = 0; j < types.length; j ++) {
      var t = types[j];
      if(regexp.exec(t.getAttribute('data-name'))){ return true; };
    };
    return false;
  };

  var search = function(text) {
    var types = document.querySelectorAll('#types-list li');
    var words = text.toLowerCase().split(/\s+/).filter(function(word) {
      return word.length > 0;
    });
    var regexp = new RegExp(words.join('|'));

    for(var i = 0; i < types.length; i++) {
      var type = types[i];
      if(words.length == 0 || regexp.exec(type.getAttribute('data-name')) || childMatch(type, regexp)) {
        type.className = type.className.replace(/ +hide/g, '');
        var is_parent     =   new RegExp("parent").exec(type.className);
        var is_not_opened = !(new RegExp("open").exec(type.className));
        if(childMatch(type,regexp) && is_parent && is_not_opened){
          type.className += " open";
        };
      } else {
        if(type.className.indexOf('hide') == -1) {
          type.className += ' hide';
        };
      };
      if(words.length == 0){
        type.className = type.className.replace(/ +open/g, '');
      };
    }
  }

  if (query) {
    searchInput.value = query;
    search(query);
  }

  var searchTimeout;
  searchInput.addEventListener('keyup', function() {
    query = searchInput.value;
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(function() { search(query); }, 200);
  });

  typesList.onscroll = function() {
    var y = typesList.scrollTop;
    sessionStorage.setItem(repositoryName + '::types-list:scrollTop', y);
  };

  var initialY = parseInt(sessionStorage.getItem(repositoryName + '::types-list:scrollTop') + "", 10);
  if(initialY > 0) {
    typesList.scrollTop = initialY;
  }
});
