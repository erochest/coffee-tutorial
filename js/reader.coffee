
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
    this.hideAll().promise().done =>
      callback() if callback?
      toShow.fadeIn()

  hideAll: ->
    @shades.add(@windows).fadeOut()

# This is the `Navigator` object. It is the model for the reader.

class Navigator
  bookmarkKey: 'reader.nav.bookmark'
  workKey: 'reader.nav.work.'

  onLoadBookName: 'loadbook.reader'
  postLoadBookName: 'postloadbook.reader'
  onOpenChapterName: 'openchapter.reader'
  onCloseChapterName: 'closechapter.reader'

  constructor: (book) ->
    @chapter = null
    @section = null
    this.load(book) if book?

  # This just defers to localStorage.
  clear: ->
    localStorage.clear()

  # Triggers `loadbook.reader.nav`, which can cancel loading the book.
  load: (book) ->
    oldBook = @book
    @book = book
    if this._loadbook(book)
      this._normalize(chapter, i) for chapter, i in book.chapters
      if this.hasBookmark()
        this.to this.getBookmark()...
      else
        @chapter = null
        @section = null
      this._postloadbook book
    else
      @book = oldBook
    this

  # This sets the enumerations on the chapters and sections so the author
  # doesn't have to. It also makes sure that every chapter has either content
  # or sections. If both are missing, empty content is inserted.
  _normalize: (chapter, i) ->
    chapter.n = i
    if chapter.sections?
      section.n = j for section, j in chapter.sections
    if not chapter.content? and not chapter.sections?
      chapter.content = ''

  getCurrentChapter: ->
    if @chapter? then @book.chapters[@chapter] else null

  getCurrentSection: ->
    chapter = this.getCurrentChapter()
    if chapter? and @section?
      chapter.sections[@section]
    else
      null

  # This checks whether the next page is accessible and silently stops
  # navigation if not.  Otherwise, it sets @chapter and triggers the
  # `reader.nav.*chapter` events. `closechapter.reader.nav` can cancel this.
  next: ->
    chapters = @book.chapters

    firstSectionFor = (chapter) ->
      if chapters[chapter].content? then null else 0

    # The default is to do nothing.
    pos = [@chapter, @section]
    log '<', pos...

    if not @chapter?
      # [null, null]
      log 'a'
      pos = [0, firstSectionFor 0]
    else if @chapter? and not @section?
      # [c, null]
      if chapters[@chapter].sections?
        log 'b'
        pos = [@chapter, 0]
      else if (@chapter + 1) < chapters.length
        log 'c'
        chapter = @chapter + 1
        pos = [chapter, firstSectionFor chapter]
    else if @chapter? and @section?
      # [c, last]
      if @section == chapters[@chapter].sections.length
        if (@chapter + 1) < chapters.length
          log 'd'
          chapter = @chapter + 1
          pos = [chapter, firstSectionFor chapter]
        # [last, last]
      else
        # [c, s]
        log 'e'
        pos = [@chapter, @section + 1]

    log '<<', pos...
    this.to pos...
    this

  # This checks whether it's already at the first page and silently stops
  # navigation if so.  Otherwise, it sets @chapter and triggers the
  # `reader.nav.*chapter` events. `closechapter.reader.nav` can cancel this.
  previous: ->
    chapters = @book.chapters

    firstSectionFor = (chapter) ->
      if chapters[chapter].content? then null else 0
    lastSectionFor = (chapter) ->
      if chapters[chapter].sections?
        chapters[chapter].sections.length - 1
      else
        null

    # The default is to do nothing
    pos = [@chapter, @section]
    log '<', pos...

    if @chapter == 0
      if not @section?
        # [0, null]
        pos = pos
      else if @section == 0
        # [0, 0]
        pos = [0, firstSectionFor 0]
      else
        # [0, s]
        pos = [0, @section - 1]
    else if @chapter?
      if not @section?
        # [c, null]
        chapter = @chapter - 1
        pos = [chapter, lastSectionFor chapter]
      else if @section == 0
        # [c, 0]
        if chapters[@chapter].content?
          pos = [@chapter, null]
        else
          chapter = @chapter - 1
          pos = [chapter, lastSectionFor chapter]
      else
        # [c, s]
        pos = [@chapter, @section - 1]
    # [null, null]

    log '<<', pos...
    this.to pos...
    this

  # This goes to the page given. If it's the same as the current page, nothing
  # happens. Otherwise, it sets @chapter and triggers the `reader.nav.*chapter`
  # events. `closechapter.reader.nav` can cancel this.
  to: (chapter, section) ->
    log 'to', chapter, section
    return if chapter == @chapter and section == @section

    if this._closechapter()
      @chapter = chapter
      this._openchapter()
      this.bookmark()

    this

  # This is the handler for the `tochapter.reader.viewer` event. It just calls
  # `.to()`.
  onToChapter: (event) ->
    this.to event.n
    event.preventDefault()

  # Most of the data storage is handled implicitly. These are the only methods
  # that provides an explicit interface to Local Storage.

  saveWork: (work) ->
    key = "#{ this.workKey }#{ @chapter }"
    localStorage[key] = work
    this

  hasWork: ->
    key = "#{ this.workKey }#{ @chapter }"
    localStorage[key]?

  getWork: ->
    key = "#{ this.workKey }#{ @chapter }"
    localStorage[key]

  bookmark: ->
    localStorage[this.bookmarkKey] = "#{@chapter}.#{@section}"

  hasBookmark: ->
    localStorage[this.bookmarkKey]?

  getBookmark: ->
    bookmark = localStorage[this.bookmarkKey]
    [ch, sec] = bookmark.split(/\./)
    [parseInt ch, parseInt sec]

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
    event.n = @chapter
    event.chapter = @book.chapters[@chapter]
    $('body').trigger event
    not event.isDefaultPrevented()

  _loadbook: (book) ->
    this._bookevent this.onLoadBookName, book

  _postloadbook: (book) ->
    this._bookevent this.postLoadBookName, book

  _openchapter: ->
    this._chapterevent this.onOpenChapterName

  _closechapter: ->
    this._chapterevent this.onCloseChapterName

  # TODO: section navigation

# This handles the Navigational Tree widget.

class NavTree
  constructor: (@elid) ->
    @el = $(@elid)

  onLoadBook: (event) ->
    this.loadBook event.book

  loadBook: (book) ->
    lis = for chapter, i in book.chapters
      this.makeChapterLi i, chapter
    ol = if lis.length > 0 then "<ol>#{ lis.join('') }</ol>" else ""
    @el.html ol

  makeChapterLi: (i, chapter) ->
    sectionOl = ""
    if chapter.sections?
      secLi = for section, j in chapter.sections
        this.makeSectionLi i, j, section 
      if secLi.length > 0
        sectionOl = "<ol>#{ secLi.join('') }</ol>"

    "<li data-chapter='#{ i }'>#{ chapter.title }#{ sectionOl }</li>"

  makeSectionLi: (i, j, section) ->
    "<li data-chapter='#{ i }' data-section='#{ j }'>#{ section.title }</li>"

  onOpenChapter: (event) ->
    chapter = event.navigator.getCurrentChapter()
    lis = @el.find('> ol > li')
    $(lis[chapter.n]).addClass 'active'

  onCloseChapter: (event) ->
    @el.find('.active').removeClass 'active'

  onClick: (event, reader) ->
    li      = $ event.target
    chapter = li.attr 'data-chapter'
    section = li.attr 'data-section'
    section = if section? then parseInt(section) else section
    log 'click', chapter, section
    if chapter?
      reader.nav.to parseInt(chapter), section


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
# It triggers the `status.reader.viewer` event, which the `Viewer` listens
# to and updates the status bar.

onStatusName = 'status.reader'

status = (source, msg) ->
  event = new jQuery.Event onStatusName
  event.source = source
  event.status = msg
  $('body').trigger event
  not event.isDefaultPrevented()

errorStatus = (source, error) ->
  log 'ERROR:', source, error
  msg = if error? and error.message? then error.message else error
  status source, msg

# This handles the view. It has listeners for the `Navigator's` events, and it
# handles updating the view based on that.

class Viewer
  onToChapterName: 'tochapter.reader'
  onEvaluateName: 'evaluate.reader'

  constructor: ->
    @shades = new WindowShade $('#fullcontent'), $('#repl').add('#contentpane')
    @shades.shades.hide()

  # When loading a new book, set the title, links, etc.
  onLoadBook: (event) ->
    book = event.book
    this.setTitle(book.title)

  postLoadBook: (event) ->
    book = event.book
    this.fullScreen(book.welcome) if book.welcome? and event.navigator.n == -1

  setTitle: (title) ->
    $('header h1').html title
    this.setStatus title

  # TODO: Move this to Reader and use .live to wire the events.
  wireTocEvents: (links) ->
    chapters = c for [a, c] in links
    ul       = $ 'nav#topmenu ul'
    select   = $ 'nav#topmenu select'

    ul.find('li a').map (i, el) =>
      $(el).click (event) =>
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
    chapter = event.navigator.getCurrentChapter()
    if chapter? and not chapter.full
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
    @nav     = new Navigator()
    @navtree = new NavTree 'nav#sidebar'
    @repl    = new Repl()
    @viewer  = new Viewer()

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
    onToChapterName = @viewer.onToChapterName
    onEvaluateName  = @viewer.onEvaluateName
    $(document)
      .bind(onToChapterName, (event) => @nav.onToChapter event)
      .bind(onEvaluateName,  (event) => @repl.onEvaluate event)
      .bind(onStatusName,    (event) => @viewer.onStatus event)

    # Navigator-generated event.
    onLoadBookName     = @nav.onLoadBookName
    postLoadBookName   = @nav.postLoadBookName
    onOpenChapterName  = @nav.onOpenChapterName
    onCloseChapterName = @nav.onCloseChapterName
    # For some reason, these aren't getting triggered.
    $(document)
      .bind(onLoadBookName,     (event) => @viewer.onLoadBook event)
      .bind(onLoadBookName,     (event) => @navtree.onLoadBook event)
      .bind(postLoadBookName,   (event) => @viewer.postLoadBook event)
      .bind(onOpenChapterName,  (event) => @viewer.onOpenChapter event)
      .bind(onOpenChapterName,  (event) => @navtree.onOpenChapter event)
      .bind(onCloseChapterName, (event) => @viewer.onCloseChapter event)
      .bind(onCloseChapterName, (event) => @navtree.onCloseChapter event)

    # Chapter events.
    $(document)
      .live('click', 'nav#sidebar li', (event) => @navtree.onClick event, reader)

window.Reader = Reader

