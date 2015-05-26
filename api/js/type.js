if (window.top == window.self) {
  console.log(pathToIndex + "#" + escape(window.location));
  window.location = pathToIndex + "#" + escape(window.location);
}
