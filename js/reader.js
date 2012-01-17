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

    Navigator.prototype.onOpenPageName = 'openpage.reader';

    Navigator.prototype.onClosePageName = 'closepage.reader';

    function Navigator(book) {
      this.chapter = null;
      this.section = null;
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
          this._normalize(chapter, i);
        }
        if (this.hasBookmark()) {
          this.to.apply(this, this.getBookmark());
        } else {
          this.chapter = null;
          this.section = null;
        }
        this._postloadbook(book);
      } else {
        this.book = oldBook;
      }
      return this;
    };

    Navigator.prototype._normalize = function(chapter, i) {
      var j, section, _len, _ref;
      chapter.n = i;
      if (chapter.sections != null) {
        _ref = chapter.sections;
        for (j = 0, _len = _ref.length; j < _len; j++) {
          section = _ref[j];
          section.n = j;
        }
      }
      if (!(chapter.content != null) && !(chapter.sections != null)) {
        return chapter.content = '';
      }
    };

    Navigator.prototype.getCurrentChapter = function() {
      if (this.chapter != null) {
        return this.book.chapters[this.chapter];
      } else {
        return null;
      }
    };

    Navigator.prototype.getCurrentSection = function() {
      var chapter;
      chapter = this.getCurrentChapter();
      if ((chapter != null) && (this.section != null)) {
        return chapter.sections[this.section];
      } else {
        return null;
      }
    };

    Navigator.prototype.firstSectionFor = function(chapter) {
      if (this.book.chapters[chapter].content != null) {
        return null;
      } else {
        return 0;
      }
    };

    Navigator.prototype.lastSectionFor = function(chapter) {
      if (this.book.chapters[chapter].sections != null) {
        return this.book.chapters[chapter].sections.length - 1;
      } else {
        return null;
      }
    };

    Navigator.prototype.next = function() {
      var chapter, chapters, pos;
      chapters = this.book.chapters;
      pos = [this.chapter, this.section];
      if (!(this.chapter != null)) {
        pos = [0, this.firstSectionFor(0)];
      } else if ((this.chapter != null) && !(this.section != null)) {
        if (chapters[this.chapter].sections != null) {
          pos = [this.chapter, 0];
        } else if ((this.chapter + 1) < chapters.length) {
          chapter = this.chapter + 1;
          pos = [chapter, this.firstSectionFor(chapter)];
        }
      } else if ((this.chapter != null) && (this.section != null)) {
        if (this.section === (chapters[this.chapter].sections.length - 1)) {
          if ((this.chapter + 1) < chapters.length) {
            chapter = this.chapter + 1;
            pos = [chapter, this.firstSectionFor(chapter)];
          }
        } else {
          pos = [this.chapter, this.section + 1];
        }
      }
      this.to.apply(this, pos);
      return this;
    };

    Navigator.prototype.previous = function() {
      var chapter, chapters, pos;
      chapters = this.book.chapters;
      pos = [this.chapter, this.section];
      if (this.chapter === 0) {
        if (!(this.section != null)) {
          pos = pos;
        } else if (this.section === 0) {
          pos = [0, this.firstSectionFor(0)];
        } else {
          pos = [0, this.section - 1];
        }
      } else if (this.chapter != null) {
        if (!(this.section != null)) {
          chapter = this.chapter - 1;
          pos = [chapter, this.lastSectionFor(chapter)];
        } else if (this.section === 0) {
          if (chapters[this.chapter].content != null) {
            pos = [this.chapter, null];
          } else {
            chapter = this.chapter - 1;
            pos = [chapter, this.lastSectionFor(chapter)];
          }
        } else {
          pos = [this.chapter, this.section - 1];
        }
      }
      this.to.apply(this, pos);
      return this;
    };

    Navigator.prototype.to = function(chapter, section) {
      if (chapter === this.chapter && section === this.section) return;
      if (this._closepage()) {
        this.chapter = chapter;
        this.section = section;
        this._openpage();
        this.bookmark();
      }
      return this;
    };

    Navigator.prototype.onToPage = function(event) {
      this.to.apply(this, event.pos);
      return event.preventDefault();
    };

    Navigator.prototype.saveWork = function(work) {
      var key;
      key = "" + this.workKey + this.chapter;
      localStorage[key] = work;
      return this;
    };

    Navigator.prototype.hasWork = function() {
      var key;
      key = "" + this.workKey + this.chapter;
      return localStorage[key] != null;
    };

    Navigator.prototype.getWork = function() {
      var key;
      key = "" + this.workKey + this.chapter;
      return localStorage[key];
    };

    Navigator.prototype.bookmark = function() {
      return localStorage[this.bookmarkKey] = "" + this.chapter + "." + this.section;
    };

    Navigator.prototype.hasBookmark = function() {
      return localStorage[this.bookmarkKey] != null;
    };

    Navigator.prototype.getBookmark = function() {
      var bookmark, mark, _i, _len, _parse, _ref, _results;
      _parse = function(n) {
        var p;
        p = parseInt(n);
        if (isNaN(p)) {
          return null;
        } else {
          return p;
        }
      };
      bookmark = localStorage[this.bookmarkKey];
      if (bookmark != null) {
        _ref = bookmark.split(/\./);
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          mark = _ref[_i];
          _results.push(_parse(mark));
        }
        return _results;
      } else {
        return [null, null];
      }
    };

    Navigator.prototype._bookevent = function(name, book) {
      var event;
      event = new jQuery.Event(name);
      event.navigator = this;
      event.book = book;
      $('body').trigger(event);
      return !event.isDefaultPrevented();
    };

    Navigator.prototype._pageevent = function(name) {
      var event;
      event = new jQuery.Event(name);
      event.navigator = this;
      event.book = this.book;
      event.pos = [this.chapter, this.section];
      event.chapter = this.getCurrentChapter();
      event.section = this.getCurrentSection();
      $('body').trigger(event);
      return !event.isDefaultPrevented();
    };

    Navigator.prototype._loadbook = function(book) {
      return this._bookevent(this.onLoadBookName, book);
    };

    Navigator.prototype._postloadbook = function(book) {
      return this._bookevent(this.postLoadBookName, book);
    };

    Navigator.prototype._openpage = function() {
      return this._pageevent(this.onOpenPageName);
    };

    Navigator.prototype._closepage = function() {
      return this._pageevent(this.onClosePageName);
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

    NavTree.prototype.onOpenPage = function(event) {
      var chapter, chli, lis, section, slis;
      chapter = event.navigator.getCurrentChapter();
      lis = this.el.find('> ol > li');
      chli = $(lis[chapter.n]);
      chli.addClass('active');
      section = event.navigator.getCurrentSection();
      if (section != null) {
        slis = chli.find('> ol > li');
        return $(slis[section.n]).addClass('active');
      }
    };

    NavTree.prototype.onClosePage = function(event) {
      return this.el.find('.active').removeClass('active');
    };

    NavTree.prototype.onClick = function(event, reader) {
      var chapter, li, section;
      li = $(event.target);
      chapter = li.attr('data-chapter');
      section = li.attr('data-section');
      section = section != null ? parseInt(section) : section;
      if (chapter != null) return reader.nav.to(parseInt(chapter), section);
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

    Viewer.prototype.onToPageName = 'topage.reader';

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
      if ((book.welcome != null) && !(event.navigator.chapter != null)) {
        return this.fullScreen(book.welcome);
      }
    };

    Viewer.prototype.setTitle = function(title) {
      $('header h1').html(title);
      return this.setStatus(title);
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

    Viewer.prototype.onClosePage = function(event) {
      var chapter;
      chapter = event.navigator.getCurrentChapter();
      if ((chapter != null) && !chapter.full) {
        event.navigator.saveWork($('#replinput').val());
      }
      return this.shades.hideAll();
    };

    Viewer.prototype.onOpenPage = function(event) {
      var chapter, divId, page, section,
        _this = this;
      chapter = event.navigator.getCurrentChapter();
      section = event.navigator.getCurrentSection();
      page = section != null ? section : chapter;
      if (!page.full && event.navigator.hasWork()) {
        $('#replinput').val(event.navigator.getWork());
      }
      this.setStatus(page.title);
      divId = page.full ? '#fullcontent div' : '#contentpane div';
      return this.shades.set(page.full, function() {
        if (page.content != null) return $(divId).html(page.content);
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
      var onClosePageName, onEvaluateName, onLoadBookName, onOpenPageName, onToPageName, postLoadBookName,
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
      onToPageName = this.viewer.onToPageName;
      onEvaluateName = this.viewer.onEvaluateName;
      $(document).bind(onToPageName, function(event) {
        return _this.nav.onToPage(event);
      }).bind(onEvaluateName, function(event) {
        return _this.repl.onEvaluate(event);
      }).bind(onStatusName, function(event) {
        return _this.viewer.onStatus(event);
      });
      onLoadBookName = this.nav.onLoadBookName;
      postLoadBookName = this.nav.postLoadBookName;
      onOpenPageName = this.nav.onOpenPageName;
      onClosePageName = this.nav.onClosePageName;
      $(document).bind(onLoadBookName, function(event) {
        return _this.viewer.onLoadBook(event);
      }).bind(onLoadBookName, function(event) {
        return _this.navtree.onLoadBook(event);
      }).bind(postLoadBookName, function(event) {
        return _this.viewer.postLoadBook(event);
      }).bind(onOpenPageName, function(event) {
        return _this.viewer.onOpenPage(event);
      }).bind(onOpenPageName, function(event) {
        return _this.navtree.onOpenPage(event);
      }).bind(onClosePageName, function(event) {
        return _this.viewer.onClosePage(event);
      }).bind(onClosePageName, function(event) {
        return _this.navtree.onClosePage(event);
      });
      return $(document).on('click', 'nav#sidebar li', {}, function(event) {
        return _this.navtree.onClick(event, reader);
      });
    };

    return Reader;

  })();

  window.Reader = Reader;

}).call(this);
