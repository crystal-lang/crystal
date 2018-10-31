function apiFromURL(url) {
  var u = new URL(url)
  return u.pathname.split("/")[2]
}

document.addEventListener('DOMContentLoaded', function() {
  var xhr = new XMLHttpRequest()
  xhr.open('GET', 'https://crystal-lang.org/api/latest/');
  xhr.onload = function(x) {
    var myVersion = apiFromURL(x.target.responseURL)
    var latestVersion = apiFromURL(window.location.href)
    iAmOutdated = myVersion < latestVersion
    if (iAmOutdated) {
      var alertBox = document.getElementById("outdated-alert")
      alertBox.innerHTML += '<div class="alert">This documentation is out of date. Click here to visit the latest version.</div>'
    }
  }
  xhr.send()
})