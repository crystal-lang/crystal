if(typeof(localStorage.settingsGithubToken) === 'undefined') {
  localStorage.settingsGithubToken = ''
}

if(typeof(localStorage.settingsShowTypes) === 'undefined') {
  localStorage.settingsShowTypes = 'true'
}

if(typeof(localStorage.settingsRunDebounce) === 'undefined') {
  localStorage.settingsRunDebounce = '800'
}

if(typeof(Playground) === 'undefined') {
  Playground = {};
}

Playground.settings = {
  getGithubToken: function() {
    return localStorage.settingsGithubToken;
  },
  getShowTypes: function() {
    return localStorage.settingsShowTypes == 'true';
  },
  getRunDebounce: function() {
    return parseInt(localStorage.settingsRunDebounce);
  }
}

$(document).ready(function(){
  var githubTokenText = $("[name=settingsGithubToken]")
  var showTypesCheck = $("[name=settingsShowTypes]")
  var runDebounceInput = $("[name=settingsRunDebounce]")

  if (githubTokenText.length > 0) {
    // settings is the current page
    githubTokenText.val(Playground.settings.getGithubToken());
    showTypesCheck.prop('checked', Playground.settings.getShowTypes());
    runDebounceInput.val(Playground.settings.getRunDebounce());

    var saveSettings = function() {
      localStorage.settingsGithubToken = githubTokenText.val();
      localStorage.settingsShowTypes = showTypesCheck.is(":checked") ? 'true' : 'false';
      localStorage.settingsRunDebounce = runDebounceInput.val();
    }

    $("input").change(function(){
      saveSettings();
    });

    window.onunload = function(){
      saveSettings();
    };
  }
});
