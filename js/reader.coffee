
# This is implemented as an ad hoc, half-assed MVC framework.
#
# Here's how it breaks down:
#
# The **models** are `Navigator` and `Repl`. This handles moving around in an
# abstract sense and saving data and positions.
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

  onLoadBookName: 'reader.nav.loadbook'
  onOpenChapterName: 'reader.nav.openchapter'
  onCloseChapterName: 'reader.nav.closechapter'

  constructor: (book) ->
    @n = -1
    this.load(book) if book?

  # This just defers to localStorage.
  clear: ->
    localStorage.clear()

  # Triggers `reader.nav.loadbook`, which can cancel loading the book.
  load: (book) ->
    if this._loadbook(book)
      chapter.n = i for chapter, i in book.chapters
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

  # This is the handler for the `reader.viewer.tochapter` event. It just calls
  # `.to()`.
  onToChapter: (event) ->
    this.to event.n
    event.preventDefault()

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
    this._bookevent this.onLoadBookName, book

  _openchapter: ->
    this._chapterevent this.onOpenChapterName

  _closechapter: ->
    this._chapterevent this.onCloseChapterName

  # TODO: section navigation

# This handles running the CoffeeScript. Having a whole model class for this is
# really pretty heavy, but I wanted to keep things tidier.

class Repl
  constructor: ->

  onEvaluate: (event) ->
    this.evaluate event.code

  evaluate: (code) ->
    try
      js = CoffeeScript.compile code
    catch error
      errorStatus error
      return
    try
      eval js
    catch error
      errorStatus error
      return

# This is a view function. It's meant to be called by the model and controller.
# It triggers the `reader.viewer.status` event, which the `Viewer` listens
# to and updates the status bar.

onStatusName = 'reader.viewer.status'

status = (source, msg) ->
  event = new jQuery.Event onStatusName
  event.source = source
  event.status = msg
  $('body').trigger event
  not event.isDefaultPrevented()

errorStatus = (source, error) ->
  msg = if error.message? then error.message else error
  status source, msg

# This handles the view. It has listeners for the `Navigator's` events, and it
# handles updating the view based on that.

class Viewer
  onToChapterName: 'reader.viewer.tochapter'
  onEvaluateName: 'reader.viewer.evaluate'

  constructor: ->
    @shades = new WindowShade $('#fullcontent'), $('#repl').add('#contentpane')
    @shades.shades.hide()

  # When loading a new book, set the title, links, etc.
  onLoadBook: (event) ->
    this.setTitle(event.book.title)
    links = this.makeChapterLink(chapter) for chapter in event.book.chapters
    this.makeToc(links)
    this.fullScreen(event.book.welcome) if event.book.welcome?

  setTitle: (title) ->
    $('header h1').html title
    this.setStatus title

  # This makes a link to a chapter title and returns the chapter itself also.
  makeChapterLink: (chapter) ->
    ["<a>#{ chapter.title }</a>", chapter]

  makeToc: (links) ->
    ul     = $ 'nav#topmenu ul'
    select = $ 'nav#topmenu select'

    ul.html(
      ( "<li>#{ a }</li>" for [a, c] in links ).join('')
    )

    options = for [a, c], i in links
                "<option value='#{ i }'>#{ c.title }</option>"
    options.unshift "<option><em>Select</em></option>"
    select.html options.join('')

    this.wireTocEvents links

  wireTocEvents: (links) ->
    chapters = c for [a, c] in links
    ul       = $ 'nav#topmenu ul'
    select   = $ 'nav#topmenu select'

    ul.find('li a').map (i, el) =>
      this._tochapter i

    select.change (event) =>
      i = parseInt select.val()
      this._tochapter i unless isNaN i
      event.preventDefault()

  _tochapter: (n) ->
    event = new jQuery.Event this.onToChapterName
    event.viewer = this
    event.n = n
    $('body').trigger event
    not event.isDefaultPrevented()

  _evaluate: (cs) ->
    event = new jQuery.Event this.onEvaluateName
    event.viewer = this
    event.code = cs
    $('body').trigger event
    not event.isDefaultPrevented()

  fullScreen: (message) ->
    @shades.shade ->
      $('#fullcontent div').html message

  # When closing a chapter, save the work, if it's visible.
  onCloseChapter: (event) ->
    if not event.navigator.getCurrentChapter().full
      event.navigator.saveWork $('#replinput').val()
    @shades.hideAll()

  # When opening a new chapter, populate the work, if it's visible.
  onOpenChapter: (event) ->
    chapter = event.navigator.getCurrentChapter()

    if not chapter.full and event.navigator.hasWork()
      $('#replinput').val event.navigator.getWork()

    this.setStatus chapter.title

    divId = if chapter.full then '#fullcontent div' else '#contentpane div'
    @shades.set chapter.full, =>
      $(divId).html chapter.content if chapter.content?

  # When the status bar needs to be updated.
  onStatus: (event) ->
    this.setStatus event.status

  setStatus: (message) ->
    $('#status').html message


# A Reader object connects with the server, loads and displays resources, and
# controls user interactions.
class Reader
  constructor: () ->
    @nav    = new Navigator()
    @repl   = new Repl()
    @viewer = new Viewer()

    this.wireEvents()

  # This makes an AJAX request to load @tocUrl and displays it.
  loadBook: (book) ->
    @nav.load book

  wireEvents: ->
    # Buttons.
    $('#btnprev').click (event) =>
      @nav.previous()
    $('#btnnext').click (event) =>
      @nav.next()
    $('#replgo').click (event) =>
      @viewer._evaluate $('#replinput').val()

    # Viewer-generated events.
    onToChapterName = Viewer.onToChapterName
    onEvaluateName  = Viewer.onEvaluateName
    $('body').bind {
      onToChapterName : (event) => @nav.onToChapter event
      onEvaluateName  : (event) => @repl.onEvaluate event
      onStatusName    : (event) => @viewer.onStatus event
    }

    # Navigator-generated event.
    onLoadBookName    = Navigator.onLoadBookName
    onOpenChapterName = Navigator.onOpenChapterName
    onCloseChapter    = Navigator.onCloseChapter
    $('body').bind {
      onLoadBookName    : (event) => @viewer.onLoadBook event
      onOpenChapterName : (event) => @viewer.onOpenChapter event
      onCloseChapter    : (event) => @viewer.onCloseChapter event
    }

window.Reader = Reader

