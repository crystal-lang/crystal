Navigator = function(sidebar, searchInput, list, leaveSearchScope){
  this.list = list;
  var self = this;

  var performingSearch = false;

  document.addEventListener('CrystalDocs:searchStarted', function(){
    performingSearch = true;
  });
  document.addEventListener('CrystalDocs:searchDebounceStarted', function(){
    performingSearch = true;
  });
  document.addEventListener('CrystalDocs:searchPerformed', function(){
    performingSearch = false;
  });
  document.addEventListener('CrystalDocs:searchDebounceStopped', function(event){
    performingSearch = false;
  });

  function delayWhileSearching(callback) {
    if(performingSearch){
      document.addEventListener('CrystalDocs:searchPerformed', function listener(){
        document.removeEventListener('CrystalDocs:searchPerformed', listener);

        // add some delay to let search results display kick in
        setTimeout(callback, 100);
      });
    }else{
      callback();
    }
  }

  function clearMoveTimeout() {
    clearTimeout(self.moveTimeout);
    self.moveTimeout = null;
  }

  function startMoveTimeout(upwards){
    /*if(self.moveTimeout) {
      clearMoveTimeout();
    }

    var go = function() {
      if (!self.moveTimeout) return;
      self.move(upwards);
      self.moveTimeout = setTimeout(go, 600);
    };
    self.moveTimeout = setTimeout(go, 800);*/
  }

  function scrollCenter(element) {
    var rect = element.getBoundingClientRect();
    var middle = sidebar.clientHeight / 2;
    sidebar.scrollTop += rect.top + rect.height / 2 - middle;
  }

  var move = this.move = function(upwards){
    if(!this.current){
      this.highlightFirst();
      return true;
    }
    var next = upwards ? this.current.previousElementSibling : this.current.nextElementSibling;
    if(next && next.classList) {
      this.highlight(next);
      scrollCenter(next);
      return true;
    }
    return false;
  };

  this.moveRight = function(){
  };
  this.moveLeft = function(){
  };

  this.highlight = function(elem) {
    if(!elem){
      return;
    }
    this.removeHighlight();

    this.current = elem;
    this.current.classList.add("current");
  };

  this.highlightFirst = function(){
    this.highlight(this.list.querySelector('li:first-child'));
  };

  this.removeHighlight = function() {
    if(this.current){
      this.current.classList.remove("current");
    }
    this.current = null;
  }

  this.openSelectedResult = function() {
    if(this.current) {
      this.current.click();
    }
  }

  this.focus = function() {
    searchInput.focus();
    searchInput.select();
    this.highlightFirst();
  }

  function handleKeyUp(event) {
    switch(event.key) {
      case "ArrowUp":
      case "ArrowDown":
      case "i":
      case "j":
      case "k":
      case "l":
      case "c":
      case "h":
      case "t":
      case "n":
      event.stopPropagation();
      clearMoveTimeout();
    }
  }

  function handleKeyDown(event) {
    switch(event.key) {
      case "Enter":
        event.stopPropagation();
        event.preventDefault();
        leaveSearchScope();
        self.openSelectedResult();
        break;
      case "Escape":
        event.stopPropagation();
        event.preventDefault();
        leaveSearchScope();
        break;
      case "j":
      case "c":
      case "ArrowUp":
        if(event.ctrlKey || event.key == "ArrowUp") {
          event.stopPropagation();
          self.move(true);
          startMoveTimeout(true);
        }
        break;
      case "k":
      case "h":
      case "ArrowDown":
        if(event.ctrlKey || event.key == "ArrowDown") {
          event.stopPropagation();
          self.move(false);
          startMoveTimeout(false);
        }
        break;
      case "k":
      case "t":
      case "ArrowLeft":
        if(event.ctrlKey || event.key == "ArrowLeft") {
          event.stopPropagation();
          self.moveLeft();
        }
        break;
      case "l":
      case "n":
      case "ArrowRight":
        if(event.ctrlKey || event.key == "ArrowRight") {
          event.stopPropagation();
          self.moveRight();
        }
        break;
    }
  }

  function handleInputKeyUp(event) {
    switch(event.key) {
      case "ArrowUp":
      case "ArrowDown":
      event.stopPropagation();
      event.preventDefault();
      clearMoveTimeout();
    }
  }

  function handleInputKeyDown(event) {
    switch(event.key) {
      case "Enter":
        event.stopPropagation();
        event.preventDefault();
        delayWhileSearching(function(){
          self.openSelectedResult();
          leaveSearchScope();
        });
        break;
      case "Escape":
        event.stopPropagation();
        event.preventDefault();
        // remove focus from search input
        leaveSearchScope();
        sidebar.focus();
        break;
      case "ArrowUp":
        event.stopPropagation();
        event.preventDefault();
        self.move(true);
        startMoveTimeout(true);
        break;

      case "ArrowDown":
        event.stopPropagation();
        event.preventDefault();
        self.move(false);
        startMoveTimeout(false);
        break;
    }
  }

  sidebar.tabIndex = 100; // set tabIndex to enable keylistener
  sidebar.addEventListener('keyup', function(event) {
    handleKeyUp(event);
  });
  sidebar.addEventListener('keydown', function(event) {
    handleKeyDown(event);
  });
  searchInput.addEventListener('keydown', function(event) {
    handleInputKeyDown(event);
  });
  searchInput.addEventListener('keyup', function(event) {
    handleInputKeyUp(event);
  });
  this.move();
};
