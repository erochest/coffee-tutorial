(function() {
  var Reader;

  Reader = (function() {

    Reader.prototype.mobileWidth = 550;

    function Reader() {
      var nav;
      log('Reader');
      nav = $('nav#topmenu');
      this.title = $('header h1');
      this.navList = nav.find('ul');
      this.navSelect = nav.find('select');
      this.main = $('#main');
      this.contentBar = $('#contentbar');
      this.content = this.contentBar.find('#content');
      this.full = this.main.find('#fullcontent');
      this.repl = $('#repl');
      this.toc = {};
      this.status = $('footer #status');
      this.n = -1;
      this.full.hide();
    }

    Reader.prototype.loadToC = function(toc) {
      var chapter, links;
      log('loadToC', toc);
      this.toc = toc;
      this.title.html(toc.title);
      links = (function() {
        var _i, _len, _ref, _results;
        _ref = toc.chapters;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          chapter = _ref[_i];
          _results.push(this.chapterLink(chapter));
        }
        return _results;
      }).call(this);
      this.populateToC(links);
      this.wireToCEvents();
      if (toc.welcome != null) this.fullScreen(toc.welcome);
      this.n = -1;
      return this;
    };

    Reader.prototype.chapterLink = function(chapter) {
      return ["<a>" + chapter.title + "</a>", chapter];
    };

    Reader.prototype.populateToC = function(links) {
      var a, i, options;
      log('populateToC', links);
      this.navList.html(((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = links.length; _i < _len; _i++) {
          a = links[_i];
          _results.push("<li>" + a[0] + "</li>");
        }
        return _results;
      })()).join(''));
      options = (function() {
        var _len, _results;
        _results = [];
        for (i = 0, _len = links.length; i < _len; i++) {
          a = links[i];
          _results.push("<option value='" + i + "'>" + a[1].title + "</option>");
        }
        return _results;
      })();
      options.unshift("<option><em>Select</em></option>");
      this.navSelect.html(options.join(''));
      return this;
    };

    Reader.prototype.wireToCEvents = function() {
      var chapters,
        _this = this;
      log('wireToCEvents');
      chapters = this.toc.chapters;
      this.navList.find('li a').map(function(i, el) {
        return _this.toChapterEvent(el, chapters[i]);
      });
      this.navSelect.change(function(event) {
        var chapter, i, val;
        val = _this.navSelect.val();
        i = parseInt(val);
        chapter = chapters[i];
        if (chapter != null) _this.toChapter(chapter);
        return event.preventDefault();
      });
      return this;
    };

    Reader.prototype.toChapterEvent = function(element, chapter) {
      var _this = this;
      return $(element).click(function(event) {
        _this.toChapter(chapter);
        return event.preventDefault();
      });
    };

    Reader.prototype.expandContent = function() {
      var _this = this;
      log('expandContent');
      this.main.find('#repl').add('#contentbar').fadeOut('normal', function() {
        return _this.full.fadeIn();
      });
      return this;
    };

    Reader.prototype.retractContent = function() {
      var _this = this;
      log('retractContent');
      this.full.fadeOut('normal', function() {
        return _this.main.find('#repl').add('#contentbar').fadeIn();
      });
      return this;
    };

    Reader.prototype.fullScreen = function(message) {
      log('fullScreen', message);
      this.expandContent();
      this.full.find('div').first().html(message);
      return this;
    };

    Reader.prototype.isFullScreen = function() {
      return this.full.is(':visible');
    };

    Reader.prototype.toChapter = function(chapter) {
      log('toChapter', chapter);
      this.n = chapter.n;
      this.setStatus("" + chapter.title + " &mdash; " + this.n);
      return this;
    };

    Reader.prototype.setStatus = function(message) {
      log('setStatus', message);
      this.status.html(message);
      return this;
    };

    return Reader;

  })();

  window.Reader = Reader;

}).call(this);
