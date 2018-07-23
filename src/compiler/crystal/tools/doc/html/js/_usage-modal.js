var UsageModal = function(title, content) {
  var $body = document.body;
  var self = this;
  var $modalBackground = document.createElement("div");
  $modalBackground.classList.add("modal-background");
  var $usageModal = document.createElement("div");
  $usageModal.classList.add("usage-modal");
  $modalBackground.appendChild($usageModal);
  var $title = document.createElement("h3");
  $title.classList.add("modal-title");
  $title.innerHTML = title
  $usageModal.appendChild($title);
  var $closeButton = document.createElement("span");
  $closeButton.classList.add("close-button");
  $closeButton.setAttribute("title", "Close modal");
  $closeButton.innerText = '×';
  $usageModal.appendChild($closeButton);
  $usageModal.insertAdjacentHTML("beforeend", content);

  $modalBackground.addEventListener('click', function(event) {
    var element = event.target || event.srcElement;

    if(element == $modalBackground) {
      self.hide();
    }
  });
  $closeButton.addEventListener('click', function(event) {
    self.hide();
  });

  $body.insertAdjacentElement('beforeend', $modalBackground);

  this.show = function(){
    $body.classList.add("js-modal-visible");
  };
  this.hide = function(){
    $body.classList.remove("js-modal-visible");
  };
  this.isVisible = function(){
    return $body.classList.contains("js-modal-visible");
  }
}
