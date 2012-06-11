// Generated by CoffeeScript 1.3.3
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  module.exports = function(testers) {
    var MyTester;
    return MyTester = (function(_super) {

      __extends(MyTester, _super);

      function MyTester() {
        return MyTester.__super__.constructor.apply(this, arguments);
      }

      MyTester.prototype.testServer = function(next) {
        var expect, fs, request, tester;
        tester = this;
        expect = testers.expect;
        request = testers.request;
        fs = require('fs');
        MyTester.__super__.testServer.apply(this, arguments);
        return this.suite('cleanurls', function(suite, test) {
          var baseUrl, outExpectedPath;
          baseUrl = "http://localhost:" + tester.docpad.config.port;
          outExpectedPath = tester.config.outExpectedPath;
          return test('server should serve URLs without an extension', function(done) {
            return request("" + baseUrl + "/welcome.html", function(err, response, actual) {
              if (err) {
                throw err;
              }
              return fs.readFile("" + outExpectedPath + "/welcome.html", function(err, expected) {
                if (err) {
                  throw err;
                }
                expect(actual.toString()).to.equal(expected.toString());
                return done();
              });
            });
          });
        });
      };

      return MyTester;

    })(testers.ServerTester);
  };

}).call(this);
