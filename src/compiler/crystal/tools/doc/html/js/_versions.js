CrystalDocs.initializeVersions = function () {
  function loadJSON(file, callback) {
    var xobj = new XMLHttpRequest();
    xobj.overrideMimeType("application/json");
    xobj.open("GET", file, true);
    xobj.onreadystatechange = function() {
      if (xobj.readyState == 4 && xobj.status == "200") {
        callback(xobj.responseText);
      }
    };
    xobj.send(null);
  }

  function parseJSON(json) {
    CrystalDocs.loadConfig(JSON.parse(json));
  }

  $elem = document.querySelector("html > head > meta[name=\"crystal_docs.json_config_url\"]")
  if ($elem == undefined) {
    return
  }
  jsonURL = $elem.getAttribute("content")
  if (jsonURL && jsonURL != "") {
    loadJSON(jsonURL, parseJSON);
  }
}

CrystalDocs.loadConfig = function (config) {
  var projectVersions = config["versions"]
  var currentVersion = document.querySelector("html > head > meta[name=\"crystal_docs.project_version\"]").getAttribute("content")

  var currentVersionInList = projectVersions.find(function (element) {
    return element.name == currentVersion
  })

  if (!currentVersionInList) {
    projectVersions.unshift({ name: currentVersion, url: '#' })
  }

  $version = document.querySelector(".project-summary > .project-version")
  $version.innerHTML = ""

  $select = document.createElement("select")
  $select.classList.add("project-versions-nav")
  $select.addEventListener("change", function () {
    window.location.href = this.value
  })
  projectVersions.forEach(function (version) {
    $item = document.createElement("option")
    $item.setAttribute("value", version.url)
    $item.append(document.createTextNode(version.name))

    if (version.name == currentVersion) {
      $item.setAttribute("selected", true)
      $item.setAttribute("disabled", true)
    }
    $select.append($item)
  });
  $form = document.createElement("form")
  $form.setAttribute("autocomplete", "off")
  $form.append($select)
  $version.append($form)
}

document.addEventListener("DOMContentLoaded", function () {
  CrystalDocs.initializeVersions()
})
