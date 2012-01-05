(function() {
  var Reader, WindowShade;

  WindowShade = (function() {

    function WindowShade(shades, windows) {
      this.shades = shades;
      this.windows = windows;
    }

    WindowShade.prototype.shade = function(callback) {
      var _this = this;
      return this.windows.fadeOut().promise().done(function() {
        if (callback != null) callback();
        return _this.shades.fadeIn();
      });
    };

    WindowShade.prototype.raise = function(callback) {
      var _this = this;
      return this.shades.fadeOut().promise().done(function() {
        if (callback != null) callback();
        return _this.windows.fadeIn();
      });
    };

    WindowShade.prototype.set = function(shaded, callback) {
      var isShaded;
      isShaded = this.isShaded();
      if (shaded && !isShaded) {
        return this.shade(callback);
      } else if (!shaded && isShaded) {
        return this.raise(callback);
      } else {
        return this.flash(callback);
      }
    };

    WindowShade.prototype.isShaded = function() {
      return this.shades.is(':visible');
    };

    WindowShade.prototype.flash = function(callback) {
      var toShow,
        _this = this;
      toShow = this.isShaded() ? this.shades : this.windows;
      return this.shades.add(this.windows).fadeOut().promise().done(function() {
        if (callback != null) callback();
        return toShow.fadeIn();
      });
    };

    return WindowShade;

  })();

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
      this.contentPane = this.main.find('#contentpane');
      this.content = this.contentPane.find('div');
      this.fullPane = this.main.find('#fullcontent');
      this.full = this.fullPane.find('div');
      this.repl = $('#repl');
      this.toc = {};
      this.status = $('footer #status');
      this.n = -1;
      this.shades = new WindowShade(this.fullPane, this.main.find('#repl').add('#contentpane'));
      this.shades.shades.hide();
    }

    Reader.prototype.loadToC = function(toc) {
      var chapter, i, links, _len, _ref;
      log('loadToC', toc);
      this.toc = toc;
      this.title.html(toc.title);
      _ref = toc.chapters;
      for (i = 0, _len = _ref.length; i < _len; i++) {
        chapter = _ref[i];
        chapter.n = i;
      }
      links = (function() {
        var _i, _len2, _ref2, _results;
        _ref2 = toc.chapters;
        _results = [];
        for (_i = 0, _len2 = _ref2.length; _i < _len2; _i++) {
          chapter = _ref2[_i];
          _results.push(this.chapterLink(chapter));
        }
        return _results;
      }).call(this);
      this.populateToC(links);
      this.wireToCEvents();
      this.wireNavEvents();
      if (toc.welcome != null) this.fullScreen(toc.welcome);
      this.setStatus(toc.title);
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

    Reader.prototype.wireNavEvents = function() {
      var _this = this;
      $('#btnfullprev').click(function(event) {
        return _this.prevChapter();
      });
      $('#btnprev').click(function(event) {
        return _this.prevChapter();
      });
      $('#btnfullnext').click(function(event) {
        return _this.nextChapter();
      });
      return $('#btnnext').click(function(event) {
        return _this.nextChapter();
      });
    };

    Reader.prototype.toChapterEvent = function(element, chapter) {
      var _this = this;
      return $(element).click(function(event) {
        _this.toChapter(chapter);
        return event.preventDefault();
      });
    };

    Reader.prototype.fullScreen = function(message) {
      var _this = this;
      log('fullScreen', message);
      this.shades.shade(function() {
        return _this.full.html(message);
      });
      return this;
    };

    Reader.prototype.isFullScreen = function() {
      return this.fullPane.is(':visible');
    };

    Reader.prototype.toChapter = function(chapter) {
      var content,
        _this = this;
      log('toChapter', chapter);
      this.n = chapter.n;
      this.setStatus("" + chapter.title);
      content = chapter.full ? this.full : this.content;
      this.shades.set(chapter.full, function() {
        if (chapter.content != null) return content.html(chapter.content);
      });
      return this;
    };

    Reader.prototype.toChapterN = function(n) {
      return this.toChapter(this.toc.chapters[n]);
    };

    Reader.prototype.prevChapter = function() {
      log('prevChapter');
      if (!(this.n <= 0)) return this.toChapterN(this.n - 1);
    };

    Reader.prototype.nextChapter = function() {
      log('nextChapter');
      if ((this.n + 1) < this.toc.chapters.length) {
        return this.toChapterN(this.n + 1);
      }
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
