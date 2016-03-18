if(typeof(Playground) === 'undefined') {
  Playground = {};
}

function hasStorage() {
  if (typeof(Storage) !== 'undefined') {
    try {
      localStorage.setItem('feature_test', 'yes');
      if (localStorage.getItem('feature_test') === 'yes') {
        localStorage.removeItem('feature_test');
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  return false;
}

Playground.hasStorage = hasStorage();

Playground.settings = {
  default: {
    settingsGithubToken: '',
    settingsShowTypes: 'true',
    settingsRunDebounce: '800'
  },
  _readSetting: function(key) {
    if(Playground.hasStorage && typeof(localStorage[key]) !== 'undefined') {
      return localStorage[key];
    }
    return Playground.settings.default[key];
  },
  _saveSetting: function(key, value) {
    if(Playground.hasStorage) {
      localStorage[key] = value;
    } else {
      console.error("Unable to save settings since localStorage is not available");
    }
  },
  getGithubToken: function() {
    return Playground.settings._readSetting('settingsGithubToken');
  },
  getShowTypes: function() {
    return Playground.settings._readSetting('settingsShowTypes') == 'true';
  },
  getRunDebounce: function() {
    return parseInt(Playground.settings._readSetting('settingsRunDebounce'));
  }
};

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
      Playground.settings._saveSetting("settingsGithubToken", githubTokenText.val());
      Playground.settings._saveSetting("settingsShowTypes", showTypesCheck.is(":checked") ? 'true' : 'false');
      Playground.settings._saveSetting("settingsRunDebounce", runDebounceInput.val());
    };

    $("input").change(function(){
      saveSettings();
    });

    window.onunload = function(){
      saveSettings();
    };
  }
});
