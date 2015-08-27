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
  var parents = document.querySelectorAll('#types-list li.parent');

  for(var i = 0; i < parents.length; i++) {
    var _parent = parents[i];
    _parent.addEventListener('click', function(e) {
      e.stopPropagation();

      if(e.target.tagName.toLowerCase() == 'li') {
        if(e.target.className.match(/open/)) {
          sessionStorage.removeItem(e.target.getAttribute('data-id'));
          e.target.className = e.target.className.replace(/ open/, '');
        } else {
          sessionStorage.setItem(e.target.getAttribute('data-id'), '1');
          e.target.className += ' open';
        }
      }
    });

    if(sessionStorage.getItem(_parent.getAttribute('data-id')) == '1') {
      _parent.className += ' open';
    }
  };

  typesList.onscroll = function() {
    var y = typesList.scrollTop;
    sessionStorage.setItem(repositoryName + '::types-list:scrollTop', y);
  };

  var initialY = parseInt(sessionStorage.getItem(repositoryName + '::types-list:scrollTop') + "", 10);
  if(initialY > 0) {
    typesList.scrollTop = initialY;
  }
});
