// Generated by CoffeeScript 1.3.3
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  module.exports = function(BasePlugin) {
    var CleanUrlsPlugin;
    return CleanUrlsPlugin = (function(_super) {

      __extends(CleanUrlsPlugin, _super);

      function CleanUrlsPlugin() {
        return CleanUrlsPlugin.__super__.constructor.apply(this, arguments);
      }

      CleanUrlsPlugin.prototype.name = 'cleanUrls';

      CleanUrlsPlugin.prototype.docpadReady = function(opts) {
        var database, docpad;
        docpad = this.docpad;
        database = docpad.getDatabase();
        docpad.log('debug', 'Applying clean urls');
        database.on('add change', function(document) {
          var documentUrl, relativeBaseUrl, relativeDirUrl;
          documentUrl = document.get('url');
          if (/\.html$/i.test(documentUrl)) {
            relativeBaseUrl = '/' + document.get('relativeBase');
            document.setUrl(relativeBaseUrl);
          }
          if (/index\.html$/i.test(documentUrl)) {
            relativeDirUrl = '/' + document.get('relativeDirPath');
            return document.setUrl(relativeDirUrl);
          }
        });
        return docpad.log('debug', 'Applied clean urls');
      };

      return CleanUrlsPlugin;

    })(BasePlugin);
  };

}).call(this);
