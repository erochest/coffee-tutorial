
# This is implemented as an ad hoc, half-assed MVC framework.
#
# Here's how it breaks down:
#
# The **model** is `Navigator`. This handles moving around in an abstract sense
# and saving data and positions.
#
# The **views** are `WindowShades` and `Viewer`. This handes displaying things
# and hiding them.
#
# The **controller** is `Reader`. I've tried to make this as light-weight as
# possible. It primarily just wires up the event handlers for the events
# triggered both by the UI and the model and views. This is also the only
# public class, so it provides the public interface.

# TODO:
# Storing code, bookmarks between pages and sessions.

# This manages the shade window. It takes two parameters: a jQuery selection of
# the covering elements (shades) and another selection of the elements that get
# covered (windows).

class WindowShade
  constructor: (@shades, @windows) ->

  shade: (callback) ->
    @windows.fadeOut().promise().done =>
        callback() if callback?
        @shades.fadeIn()

  raise: (callback) ->
    @shades.fadeOut().promise().done =>
      callback() if callback?
      @windows.fadeIn()

  set: (shaded, callback) ->
    isShaded = this.isShaded()
    if shaded and not isShaded
      this.shade(callback)
    else if not shaded and isShaded
      this.raise(callback)
    else
      this.flash(callback)

  isShaded: ->
    @shades.is(':visible')

  flash: (callback) ->
    toShow = if this.isShaded() then @shades else @windows
    @shades.add(@windows).fadeOut().promise().done =>
      callback() if callback?
      toShow.fadeIn()

# This is the `Navigator` object. It is the model for the reader.

class Navigator
  bookmarkKey: 'reader.nav.bookmark'
  workKey: 'reader.nav.work.'

  constructor: (book) ->
    @n = -1
    this.load(book)

  # This just defers to localStorage.
  clear: ->
    localStorage.clear()

  # Triggers `reader.nav.loadbook`, which can cancel loading the book.
  load: (book) ->
    if this._loadbook(book)
      @book = book
      @n = if this.hasBookmark() then this.getBookmark() else -1
    this

  getCurrentChapter: ->
    @book.chapters[@n]

  # This checks whether the next page is accessible and silently stops
  # navigation if not.  Otherwise, it sets @n and triggers the
  # `reader.nav.*chapter` events. `reader.nav.close.chapter` can cancel this.
  next: ->
    next = @n + 1
    this.to next if next < @book.chapters.length
    this

  # This checks whether it's already at the first page and silently stops
  # navigation if so.  Otherwise, it sets @n and triggers the
  # `reader.nav.*chapter` events. `reader.nav.close.chapter` can cancel this.
  previous: ->
    this.to(@n - 1) if @n > 0
    this

  # This goes to the page given. If it's the same as the current page, nothing
  # happens. Otherwise, it sets @n and triggers the `reader.nav.*chapter`
  # events. `reader.nav.close.chapter` can cancel this.
  to: (n) ->
    return if n == @n

    if this._closechapter()
      @n = n
      this._openchapter()
      this.bookmark()

    this

  # Most of the data storage is handled implicitly. These are the only methods
  # that provides an explicit interface to Local Storage.

  saveWork: (work) ->
    key = "#{ this.workKey }#{ @n }"
    localStorage[key] = work
    this

  hasWork: ->
    key = "#{ this.workKey }#{ @n }"
    localStorage[key]?

  getWork: ->
    key = "#{ this.workKey }#{ @n }"
    localStorage[key]

  bookmark: ->
    localStorage[this.bookmarkKey] = @n

  hasBookmark: ->
    localStorage[this.bookmarkKey]?

  getBookmark: ->
    parseInt(localStorage[this.bookmarkKey])

  # These methods handle triggering the `Navigator` events. The first two are
  # abstract methods for triggering classes of events. The last three use the
  # first two methods to trigger specific events.
  #
  # All of these return `false` if `event.preventDefault()` was called by a
  # handler. Code calling these can test and possibly cancel further
  # processing.

  _bookevent: (name, book) ->
    event = new jQuery.Event name
    event.navigator = this
    event.book = book
    $('body').trigger event
    not event.isDefaultPrevented()

  _chapterevent: (name) ->
    event = new jQuery.Event name
    event.navigator = this
    event.book = @book
    event.n = @n
    event.chapter = @book.chapters[@n]
    $('body').trigger event
    not event.isDefaultPrevented()

  _loadbook: (book) ->
    this._bookevent 'reader.nav.loadbook', book

  _openchapter: ->
    this._chapterevent 'reader.nav.openchapter'

  _closechapter: ->
    this._chapterevent 'reader.nav.closechapter'

  # TODO: section navigation


# This handles interacting the Local Storage. This both listens to navigation
# events and pulls information from the viewer to get 


# A Reader object connects with the server, loads and displays resources, and
# controls user interactions.
class Reader
  mobileWidth: 550

  constructor: () ->
    log 'Reader'
    nav          = $ 'nav#topmenu'
    @title       = $ 'header h1'
    @navList     = nav.find 'ul'
    @navSelect   = nav.find 'select'
    @main        = $ '#main'
    @contentPane = @main.find '#contentpane'
    @content     = @contentPane.find 'div'
    @fullPane    = @main.find '#fullcontent'
    @full        = @fullPane.find 'div'
    @repl        = $ '#repl'
    @replInput   = @repl.find '#replinput'
    @toc         = {}
    @status      = $ 'footer #status'
    @n           = -1

    @shades = new WindowShade(
      @fullPane,
      @main.find('#repl').add('#contentpane')
    )
    @shades.shades.hide()

  # This makes an AJAX request to load @tocUrl and displays it.
  loadToC: (toc) ->
    log 'loadToC', toc
    @toc = toc
    @title.html(toc.title)

    chapter.n = i for chapter, i in toc.chapters

    links = (this.chapterLink(chapter) for chapter in toc.chapters)
    this.populateToC(links)
    this.wireToCEvents()
    this.wireNavEvents()
    this.wireGoEvent()

    this.fullScreen(toc.welcome) if toc.welcome?
    this.setStatus toc.title
    @n = -1

    this

  # This creates the chapter link and returns the chapter also.
  chapterLink: (chapter) ->
    ["<a>#{ chapter.title }</a>", chapter]

  # This clears the links and re-populates them from the 
  populateToC: (links) ->
    log 'populateToC', links
    @navList.html(
      ( "<li>#{ a[0] }</li>" for a in links ).join('')
    )

    options = for a, i in links
                "<option value='#{ i }'>#{ a[1].title }</option>" 
    options.unshift "<option><em>Select</em></option>"
    @navSelect.html options.join('')

    this

  # This walks through the ToC links that were created, wires them up, and
  # removes their default handling.
  wireToCEvents: () ->
    log 'wireToCEvents'
    chapters = @toc.chapters

    @navList.find('li a').map (i, el) =>
      this.toChapterEvent(el, chapters[i])

    @navSelect.change (event) =>
      val = @navSelect.val()
      i = parseInt val
      chapter = chapters[i]
      if chapter?
        this.toChapter chapter
      event.preventDefault()

    this

  wireNavEvents: ->
    $('#btnfullprev').click (event) =>
      this.prevChapter()
    $('#btnprev').click (event) =>
      this.prevChapter()
    $('#btnfullnext').click (event) =>
      this.nextChapter()
    $('#btnnext').click (event) =>
      this.nextChapter()

  # This wires up the CoffeeScript compiler.
  wireGoEvent: ->
    $('#replgo').click (event) =>
      this.execCS @replInput.val()

  # This actually takes care of wiring up the event.
  toChapterEvent: (element, chapter) ->
    $(element).click (event) =>
      this.toChapter(chapter)
      event.preventDefault()

  fullScreen: (message) ->
    log 'fullScreen', message
    @shades.shade =>
      @full.html message
    this

  isFullScreen: ->
    @fullPane.is(':visible')

  toChapter: (chapter) ->
    log 'toChapter', chapter
    @n = chapter.n
    this.setStatus "#{chapter.title}"

    content = if chapter.full then @full else @content
    @shades.set chapter.full, =>
      content.html(chapter.content) if chapter.content?

    this

  toChapterN: (n) ->
    this.toChapter @toc.chapters[n]

  prevChapter: ->
    log 'prevChapter'
    this.toChapterN(@n-1) unless @n <= 0

  nextChapter: ->
    log 'nextChapter'
    this.toChapterN(@n+1) if (@n + 1) < @toc.chapters.length

  setStatus: (message) ->
    log 'setStatus', message
    @status.html(message)
    this

  setErrorStatus: (error) ->
    msg = if error.message? then error.message else error
    this.setStatus msg

  execCS: (source) ->
    try
      js = CoffeeScript.compile source
    catch error
      this.setErrorStatus error
      return
    try
      eval(js)
    catch error
      this.setErrorStatus error
      return

window.Reader = Reader

