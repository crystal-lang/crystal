window.CrystalDoc = (window['CrystalDoc'] || {});

CrystalDoc.searchIndex = { typeIdx: {}, methodIdx: {} };

CrystalDoc.gramNum = 2;
CrystalDoc.defaultFuzzLevel = .5;

CrystalDoc.ngram = function(words, n) {
  var grams = [];

  for(var i = 0; i <= words.length - n; i++) {
    grams.push(words.substr(i, n).toLowerCase());
  }

  return grams;
};

CrystalDoc.indexing = function(genre, name, no) {
  genre = genre + 'Idx';

  CrystalDoc.ngram(name, CrystalDoc.gramNum).forEach(function(gram, index, array) {
    var list = CrystalDoc.searchIndex[genre][gram] || {};

    if(list[no]) {
      list[no].push(index);
    } else {
      list[no] = [index];
    }

    CrystalDoc.searchIndex[genre][gram] = list;
  });
};

CrystalDoc.search = function(genre, words, fuzzyLevel) {
  if(!fuzzyLevel) { fuzzyLevel = CrystalDoc.defaultFuzzLevel };
  var index = CrystalDoc.searchIndex[genre + 'Idx'];
  var grams = CrystalDoc.ngram(words, CrystalDoc.gramNum);

  var hits = {};
  grams.forEach(function(gram, _, __) {
    var hitEntries = index[gram];

    Object.keys(hitEntries || {}).forEach(function(no, _, __) {
      if(hits[no]) {
        hits[no]++;
      } else {
        hits[no] = 1;
      }
    });
  });

  var result = Object.keys(hits).filter(function(no) {
    var count = hits[no];

    return count >= (grams.length * fuzzyLevel);
  });

  return result.map(function(n) { return parseInt(n, 10) });
};

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
  var methodsList = document.getElementById('methods-list');
  var searchInput = document.getElementById('search-input');
  var fuzzySearch = document.getElementById('fuzzy-search');
  var parents = document.querySelectorAll('#types-list li.parent');
  var tabSelectors = document.querySelectorAll('#search-box ul li a');
  var wrapper = document.getElementById('wrapper');
  var main = document.getElementById('main-content');
  var sidebarOpener = document.getElementById('sidebar-opener');

  var types = document.querySelectorAll('#types-list li');
  for(var i = 0; i < types.length; i++) {
    var type = types[i];
    var name = type.getAttribute('data-name');

    if(name) {
      CrystalDoc.indexing('type', name, i);
    }
  }

  var methods = document.querySelectorAll('#methods-list li');
  for(var i = 0; i < methods.length; i++) {
    var method = methods[i];
    var name = method.getAttribute('data-name');

    if(name) {
      CrystalDoc.indexing('method', name, i);
    }
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
  };

  var selectTab = function(name) {
    var link = document.querySelectorAll('a[href="#' + name + '"]')[0];

    if(link) {
      var currents = document.querySelectorAll('#search-box ul li.current, #side-list div.current');
      for(var i = 0; i < currents.length; i++) {
        currents[i].className = currents[i].className.replace(/(^| +)current/g, '');
      }

      link.parentElement.className += ' current';
      var tab = document.getElementById(name);
      tab.className += ' current';

      sessionStorage.setItem(repositoryName + '::currentTab', name);
    }
  };

  for(var i = 0; i < tabSelectors.length; i++) {
    var tabSelector = tabSelectors[i];
    tabSelector.addEventListener('click', function(e) {
      e.preventDefault();

      selectTab(e.target.getAttribute('href').slice(1));
    });
  };

  var childMatch = function(type, regexp){
    var types = type.querySelectorAll("ul li");
    for (var j = 0; j < types.length; j ++) {
      var t = types[j];
      if(regexp.exec(t.getAttribute('data-name'))){ return true; };
    };
    return false;
  };

  var openAll = function(type) {
    type.className = type.className.replace(/ +hide/g, '');

    if(type.className.indexOf('open') == -1 && type.className.indexOf('parent') != -1) {
      type.className += ' open';
    };

    if(type.parentElement.id != 'types-list') {
      openAll(type.parentElement);
    }
  };

  var search = function(text) {
    var fuzzyLevel = fuzzySearch.checked ? CrystalDoc.defaultFuzzLevel : 1;

    var words = text.toLowerCase().split(/\s+/).filter(function(word) {
      return word.length > 0;
    });

    var typeResults = words.map(function(word) {
      return CrystalDoc.search('type', word, fuzzyLevel)
    });
    typeResults = Array.prototype.concat.apply([], typeResults).filter(function(x, i, self) {
      return self.indexOf(x) === i;
    });

    var methodResults = words.map(function(word) {
      return CrystalDoc.search('method', word, fuzzyLevel)
    });
    methodResults = Array.prototype.concat.apply([], methodResults).filter(function(x, i, self) {
      return self.indexOf(x) === i;
    });

    for(var i = 0; i < types.length; i++) {
      var type = types[i];

      if(words.length == 0 || typeResults.indexOf(i) != -1) {
        type.className = type.className.replace(/ +hide/g, '');

        if(words.length != 0) {
          openAll(type);
        } else {
          if(!sessionStorage.getItem(type.getAttribute('data-id'))) {
            type.className = type.className.replace(/ +open/g, '');
          }
        }
      } else {
        if(type.className.indexOf('hide') == -1) {
          type.className += ' hide';
        };
      };
    }

    for(var i = 0; i < methods.length; i++) {
      var method = methods[i];

      if(words.length == 0 || methodResults.indexOf(i) != -1) {
        method.className = method.className.replace(/ +hide/g, '');
      } else {
        if(method.className.indexOf('hide') == -1) {
          method.className += ' hide';
        };
      }
    };
  };

  searchInput.addEventListener('input', function() {
    var text = searchInput.value;
    search(text);
    sessionStorage.setItem(repositoryName + ':::searchText', text);
  });

  fuzzySearch.addEventListener('change', function() {
    var text = searchInput.value;
    search(text);

    if(fuzzySearch.checked) {
      sessionStorage.setItem(repositoryName + ':::fuzzySearch', 'true');
    } else {
      sessionStorage.removeItem(repositoryName + ':::fuzzySearch');
    }
  });

  var searchTimeout;
  searchInput.addEventListener('keyup', function() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(function() {
      var text = searchInput.value;
      search(text);
      sessionStorage.setItem(repositoryName + ':::searchText', text);
    }, 200);
  });

  sidebarOpener.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();

    wrapper.className = 'sidebar-opened';
  });

  main.addEventListener('click', function(e) {
    if(wrapper.className.indexOf('sidebar-opened') == -1) {
      return;
    }

    e.preventDefault();
    wrapper.className = '';
  });

  typesList.onscroll = function() {
    var y = typesList.scrollTop;
    sessionStorage.setItem(repositoryName + '::types-list:scrollTop', y);
  };

  var initialTypesY = parseInt(sessionStorage.getItem(repositoryName + '::types-list:scrollTop') + "", 10);
  if(initialTypesY > 0) {
    typesList.scrollTop = initialTypesY;
  }

  methodsList.onscroll = function() {
    var y = methodsList.scrollTop;
    sessionStorage.setItem(repositoryName + '::methods-list:scrollTop', y);
  };

  var initialMethodsY = parseInt(sessionStorage.getItem(repositoryName + '::methods-list:scrollTop') + "", 10);
  if(initialMethodsY > 0) {
    methodsList.scrollTop = initialMethodsY;
  }

  var initialTab = sessionStorage.getItem(repositoryName + '::currentTab');
  if(initialTab && initialTab.length > 0) {
    selectTab(initialTab);
  }

  var initialFuzzy = sessionStorage.getItem(repositoryName + ':::fuzzySearch') + '';
  if(initialFuzzy == 'true') {
    fuzzySearch.checked = true;
  }

  var initialSearch = sessionStorage.getItem(repositoryName + ':::searchText');
  if(initialSearch && initialSearch.length > 0) {
    searchInput.value = initialSearch;
    search(initialSearch);
  }
});
