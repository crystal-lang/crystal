if(typeof(localStorage.settingsGithubToken) === 'undefined') {
  localStorage.settingsGithubToken = ''
}

if(typeof(localStorage.settingsShowTypes) === 'undefined') {
  localStorage.settingsShowTypes = 'true'
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
  }
}

$(document).ready(function(){
  var githubTokenText = $("[name=settingsGithubToken]")
  var showTypesCheck = $("[name=settingsShowTypes]")

  if (githubTokenText.length > 0) {
    // settings is the current page
    githubTokenText.val(Playground.settings.getGithubToken());
    showTypesCheck.prop('checked', Playground.settings.getShowTypes());

    var saveSettings = function() {
      localStorage.settingsGithubToken = githubTokenText.val();
      localStorage.settingsShowTypes = showTypesCheck.is(":checked") ? 'true' : 'false';
    }

    $("input").change(function(){
      saveSettings();
    });

    window.onunload = function(){
      saveSettings();
    };
  }
});
