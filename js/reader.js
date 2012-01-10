(function() {
  var NavTree, Navigator, Reader, Repl, Viewer, WindowShade, errorStatus, onStatusName, status;

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
      return this.hideAll().promise().done(function() {
        if (callback != null) callback();
        return toShow.fadeIn();
      });
    };

    WindowShade.prototype.hideAll = function() {
      return this.shades.add(this.windows).fadeOut();
    };

    return WindowShade;

  })();

  Navigator = (function() {

    Navigator.prototype.bookmarkKey = 'reader.nav.bookmark';

    Navigator.prototype.workKey = 'reader.nav.work.';

    Navigator.prototype.onLoadBookName = 'loadbook.reader';

    Navigator.prototype.postLoadBookName = 'postloadbook.reader';

    Navigator.prototype.onOpenChapterName = 'openchapter.reader';

    Navigator.prototype.onCloseChapterName = 'closechapter.reader';

    function Navigator(book) {
      this.n = -1;
      if (book != null) this.load(book);
    }

    Navigator.prototype.clear = function() {
      return localStorage.clear();
    };

    Navigator.prototype.load = function(book) {
      var chapter, i, oldBook, _len, _ref;
      oldBook = this.book;
      this.book = book;
      if (this._loadbook(book)) {
        _ref = book.chapters;
        for (i = 0, _len = _ref.length; i < _len; i++) {
          chapter = _ref[i];
          chapter.n = i;
        }
        if (this.hasBookmark()) {
          this.to(this.getBookmark());
        } else {
          this.n = -1;
        }
        this._postloadbook(book);
      } else {
        this.book = oldBook;
      }
      return this;
    };

    Navigator.prototype.getCurrentChapter = function() {
      return this.book.chapters[this.n];
    };

    Navigator.prototype.next = function() {
      var next;
      next = this.n + 1;
      if (next < this.book.chapters.length) this.to(next);
      return this;
    };

    Navigator.prototype.previous = function() {
      if (this.n > 0) this.to(this.n - 1);
      return this;
    };

    Navigator.prototype.to = function(n) {
      if (n === this.n) return;
      if (this._closechapter()) {
        this.n = n;
        this._openchapter();
        this.bookmark();
      }
      return this;
    };

    Navigator.prototype.onToChapter = function(event) {
      this.to(event.n);
      return event.preventDefault();
    };

    Navigator.prototype.saveWork = function(work) {
      var key;
      key = "" + this.workKey + this.n;
      localStorage[key] = work;
      return this;
    };

    Navigator.prototype.hasWork = function() {
      var key;
      key = "" + this.workKey + this.n;
      return localStorage[key] != null;
    };

    Navigator.prototype.getWork = function() {
      var key;
      key = "" + this.workKey + this.n;
      return localStorage[key];
    };

    Navigator.prototype.bookmark = function() {
      return localStorage[this.bookmarkKey] = this.n;
    };

    Navigator.prototype.hasBookmark = function() {
      return localStorage[this.bookmarkKey] != null;
    };

    Navigator.prototype.getBookmark = function() {
      return parseInt(localStorage[this.bookmarkKey]);
    };

    Navigator.prototype._bookevent = function(name, book) {
      var event;
      event = new jQuery.Event(name);
      event.navigator = this;
      event.book = book;
      $('body').trigger(event);
      return !event.isDefaultPrevented();
    };

    Navigator.prototype._chapterevent = function(name) {
      var event;
      event = new jQuery.Event(name);
      event.navigator = this;
      event.book = this.book;
      event.n = this.n;
      event.chapter = this.book.chapters[this.n];
      $('body').trigger(event);
      return !event.isDefaultPrevented();
    };

    Navigator.prototype._loadbook = function(book) {
      return this._bookevent(this.onLoadBookName, book);
    };

    Navigator.prototype._postloadbook = function(book) {
      return this._bookevent(this.postLoadBookName, book);
    };

    Navigator.prototype._openchapter = function() {
      return this._chapterevent(this.onOpenChapterName);
    };

    Navigator.prototype._closechapter = function() {
      return this._chapterevent(this.onCloseChapterName);
    };

    return Navigator;

  })();

  NavTree = (function() {

    function NavTree(elid) {
      this.elid = elid;
      this.el = $(this.elid);
    }

    NavTree.prototype.onLoadBook = function(event) {
      return this.loadBook(event.book);
    };

    NavTree.prototype.loadBook = function(book) {
      var chapter, i, lis, ol;
      lis = (function() {
        var _len, _ref, _results;
        _ref = book.chapters;
        _results = [];
        for (i = 0, _len = _ref.length; i < _len; i++) {
          chapter = _ref[i];
          _results.push(this.makeChapterLi(i, chapter));
        }
        return _results;
      }).call(this);
      ol = lis.length > 0 ? "<ol>" + (lis.join('')) + "</ol>" : "";
      return this.el.html(ol);
    };

    NavTree.prototype.makeChapterLi = function(i, chapter) {
      var j, secLi, section, sectionOl;
      sectionOl = "";
      if (chapter.sections != null) {
        secLi = (function() {
          var _len, _ref, _results;
          _ref = chapter.sections;
          _results = [];
          for (j = 0, _len = _ref.length; j < _len; j++) {
            section = _ref[j];
            _results.push(this.makeSectionLi(i, j, section));
          }
          return _results;
        }).call(this);
        if (secLi.length > 0) sectionOl = "<ol>" + (secLi.join('')) + "</ol>";
      }
      return "<li data-chapter='" + i + "'>" + chapter.title + sectionOl + "</li>";
    };

    NavTree.prototype.makeSectionLi = function(i, j, section) {
      return "<li data-chapter='" + i + "' data-section='" + j + "'>" + section.title + "</li>";
    };

    NavTree.prototype.onOpenChapter = function(event) {
      var chapter, lis;
      chapter = event.navigator.getCurrentChapter();
      lis = this.el.find('> ol > li');
      log(lis, chapter.n, lis[chapter.n]);
      return $(lis[chapter.n]).addClass('active');
    };

    NavTree.prototype.onCloseChapter = function(event) {
      return this.el.find('.active').removeClass('active');
    };

    NavTree.prototype.onClick = function(event, reader) {
      var chapter, li, section;
      li = $(event.target);
      chapter = li.attr('data-chapter');
      section = li.attr('data-section');
      if (chapter != null) return reader.nav.to(parseInt(chapter));
    };

    return NavTree;

  })();

  Repl = (function() {

    function Repl() {}

    Repl.prototype.onEvaluate = function(event) {
      return this.evaluate(event.code);
    };

    Repl.prototype.evaluate = function(code) {
      var js;
      try {
        js = CoffeeScript.compile(code);
      } catch (error) {
        errorStatus(error);
        return;
      }
      try {
        return eval(js);
      } catch (error) {
        errorStatus(error);
      }
    };

    return Repl;

  })();

  onStatusName = 'status.reader';

  status = function(source, msg) {
    var event;
    event = new jQuery.Event(onStatusName);
    event.source = source;
    event.status = msg;
    $('body').trigger(event);
    return !event.isDefaultPrevented();
  };

  errorStatus = function(source, error) {
    var msg;
    log('ERROR:', source, error);
    msg = (error != null) && (error.message != null) ? error.message : error;
    return status(source, msg);
  };

  Viewer = (function() {

    Viewer.prototype.onToChapterName = 'tochapter.reader';

    Viewer.prototype.onEvaluateName = 'evaluate.reader';

    function Viewer() {
      this.shades = new WindowShade($('#fullcontent'), $('#repl').add('#contentpane'));
      this.shades.shades.hide();
    }

    Viewer.prototype.onLoadBook = function(event) {
      var book;
      book = event.book;
      return this.setTitle(book.title);
    };

    Viewer.prototype.postLoadBook = function(event) {
      var book;
      book = event.book;
      if ((book.welcome != null) && event.navigator.n === -1) {
        return this.fullScreen(book.welcome);
      }
    };

    Viewer.prototype.setTitle = function(title) {
      $('header h1').html(title);
      return this.setStatus(title);
    };

    Viewer.prototype.wireTocEvents = function(links) {
      var a, c, chapters, select, ul, _i, _len, _ref,
        _this = this;
      for (_i = 0, _len = links.length; _i < _len; _i++) {
        _ref = links[_i], a = _ref[0], c = _ref[1];
        chapters = c;
      }
      ul = $('nav#topmenu ul');
      select = $('nav#topmenu select');
      ul.find('li a').map(function(i, el) {
        return $(el).click(function(event) {
          return _this._tochapter(i);
        });
      });
      return select.change(function(event) {
        var i;
        i = parseInt(select.val());
        if (!isNaN(i)) _this._tochapter(i);
        return event.preventDefault();
      });
    };

    Viewer.prototype._tochapter = function(n) {
      var event;
      event = new jQuery.Event(this.onToChapterName);
      event.viewer = this;
      event.n = n;
      $('body').trigger(event);
      return !event.isDefaultPrevented();
    };

    Viewer.prototype._evaluate = function(cs) {
      var event;
      event = new jQuery.Event(this.onEvaluateName);
      event.viewer = this;
      event.code = cs;
      $('body').trigger(event);
      return !event.isDefaultPrevented();
    };

    Viewer.prototype.fullScreen = function(message) {
      return this.shades.shade(function() {
        return $('#fullcontent div').html(message);
      });
    };

    Viewer.prototype.onCloseChapter = function(event) {
      var chapter;
      chapter = event.navigator.getCurrentChapter();
      if ((chapter != null) && !chapter.full) {
        event.navigator.saveWork($('#replinput').val());
      }
      return this.shades.hideAll();
    };

    Viewer.prototype.onOpenChapter = function(event) {
      var chapter, divId,
        _this = this;
      chapter = event.navigator.getCurrentChapter();
      if (!chapter.full && event.navigator.hasWork()) {
        $('#replinput').val(event.navigator.getWork());
      }
      this.setStatus(chapter.title);
      divId = chapter.full ? '#fullcontent div' : '#contentpane div';
      return this.shades.set(chapter.full, function() {
        if (chapter.content != null) return $(divId).html(chapter.content);
      });
    };

    Viewer.prototype.onStatus = function(event) {
      return this.setStatus(event.status);
    };

    Viewer.prototype.setStatus = function(message) {
      return $('#status').html(message);
    };

    return Viewer;

  })();

  Reader = (function() {

    function Reader() {
      this.nav = new Navigator();
      this.navtree = new NavTree('nav#sidebar');
      this.repl = new Repl();
      this.viewer = new Viewer();
      this.wireEvents();
    }

    Reader.prototype.loadBook = function(book) {
      return this.nav.load(book);
    };

    Reader.prototype.wireEvents = function() {
      var onCloseChapterName, onEvaluateName, onLoadBookName, onOpenChapterName, onToChapterName, postLoadBookName,
        _this = this;
      $('#btnprev').click(function(event) {
        return _this.nav.previous();
      });
      $('#btnnext').click(function(event) {
        return _this.nav.next();
      });
      $('#replgo').click(function(event) {
        return _this.viewer._evaluate($('#replinput').val());
      });
      onToChapterName = this.viewer.onToChapterName;
      onEvaluateName = this.viewer.onEvaluateName;
      $(document).bind(onToChapterName, function(event) {
        return _this.nav.onToChapter(event);
      }).bind(onEvaluateName, function(event) {
        return _this.repl.onEvaluate(event);
      }).bind(onStatusName, function(event) {
        return _this.viewer.onStatus(event);
      });
      onLoadBookName = this.nav.onLoadBookName;
      postLoadBookName = this.nav.postLoadBookName;
      onOpenChapterName = this.nav.onOpenChapterName;
      onCloseChapterName = this.nav.onCloseChapterName;
      $(document).bind(onLoadBookName, function(event) {
        return _this.viewer.onLoadBook(event);
      }).bind(onLoadBookName, function(event) {
        return _this.navtree.onLoadBook(event);
      }).bind(postLoadBookName, function(event) {
        return _this.viewer.postLoadBook(event);
      }).bind(onOpenChapterName, function(event) {
        return _this.viewer.onOpenChapter(event);
      }).bind(onOpenChapterName, function(event) {
        return _this.navtree.onOpenChapter(event);
      }).bind(onCloseChapterName, function(event) {
        return _this.viewer.onCloseChapter(event);
      }).bind(onCloseChapterName, function(event) {
        return _this.navtree.onCloseChapter(event);
      });
      return $(document).live('click', 'nav#sidebar li', function(event) {
        return _this.navtree.onClick(event, reader);
      });
    };

    return Reader;

  })();

  window.Reader = Reader;

}).call(this);
