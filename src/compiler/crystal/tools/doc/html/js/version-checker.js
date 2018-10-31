function apiFromURL(url) {
  var u = new URL(url)
  return u.pathname.split("/")[2]
}

document.addEventListener('DOMContentLoaded', function() {
  var xhr = new XMLHttpRequest()
  xhr.open('GET', '/api/latest/');
  xhr.onload = function(x) {
    var myVersion = apiFromURL(window.location.href)
    var latestVersion = apiFromURL(x.target.responseURL)
    iAmOutdated = myVersion < latestVersion
    if (iAmOutdated) {
      var alertBox = document.getElementById("outdated-alert")
      alertBox.innerHTML += '<div class="alert">This documentation is out of date. Click here to visit the latest version.</div>'
    }
  }
  xhr.send()
})