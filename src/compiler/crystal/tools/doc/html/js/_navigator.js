Navigator = function(sidebar, searchInput, list){
  this.list = list;
  var self = this;

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
      self.moveTimout = setTimeout(go, 600);
    };
    self.moveTimeout = setTimeout(go, 800);*/
  }

  var move = this.move = function(upwards){
    if(!this.current){
      this.highlightFirst();
      return true;
    }
    var next = upwards ? this.current.previousElementSibling : this.current.nextElementSibling;
    if(next && next.classList) {
      this.highlight(next);
      next.scrollIntoViewIfNeeded();
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
    if(this.current){
      this.current.classList.remove("current");
    }

    this.current = elem;
    this.current.classList.add("current");
  };

  this.highlightFirst = function(){
    this.highlight(this.list.querySelector('li:first-child'));
  };

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
        self.current.click();
        break;
      case "Escape":
        event.stopPropagation();
        CrystalDoc.toggleResultsList(false);
        sessionStorage.setItem(repositoryName + '::search-input:value', "");
        break;
      case "i":
      case "c":
      case "ArrowUp":
        if(event.ctrlKey || event.key == "ArrowUp") {
          event.stopPropagation();
          self.move(true);
          startMoveTimeout(true);
        }
        break;
      case "j":
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
      clearMoveTimeout();
    }
  }

  function handleInputKeyDown(event) {
    switch(event.key) {
      case "Enter":
        event.stopPropagation();
        self.current.click();
        break;
      case "Escape":
        event.stopPropagation();
        event.preventDefault();
        // remove focus from search input
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
