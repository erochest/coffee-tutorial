
# TODO:
# Storing code, bookmarks between pages and sessions.

# This manages the shade window. It takes two parameters: a jQuery selection of
# the covering elements (shades) and another selection of the elements that get
# covered (windows).

class WindowShade
  constructor: (@shades, @windows) ->

  shade: ->
    @windows.fadeOut 'normal', => @shades.fadeIn()

  raise: ->
    @shades.fadeOut 'normal', => @windows.fadeIn()

  set: (shaded) ->
    isShaded = this.isShaded()
    if shaded and not isShaded
      this.shade()
    else if not shaded and isShaded
      this.raise()

  isShaded: ->
    @shades.is(':visible')


# A Reader object connects with the server, loads and displays resources, and
# controls user interactions.
class Reader
  mobileWidth: 550

  constructor: () ->
    log 'Reader'
    nav = $ 'nav#topmenu'
    @title      = $ 'header h1'
    @navList    = nav.find 'ul'
    @navSelect  = nav.find 'select'
    @main       = $ '#main'
    @contentBar = $ '#contentbar'
    @content    = @contentBar.find '#content'
    @full       = @main.find '#fullcontent'
    @repl       = $ '#repl'
    @toc        = {}
    @status     = $ 'footer #status'
    @n          = -1

    @shades = new WindowShade(
      @full,
      @main.find('#repl').add('#contentbar')
    )
    @shades.shades.hide()

  # This makes an AJAX request to load @tocUrl and displays it.
  loadToC: (toc) ->
    log 'loadToC', toc
    @toc = toc
    @title.html(toc.title)

    links = (this.chapterLink(chapter) for chapter in toc.chapters)
    this.populateToC(links)
    this.wireToCEvents()
    this.wireNavEvents()

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

  # This actually takes care of wiring up the event.
  toChapterEvent: (element, chapter) ->
    $(element).click (event) =>
      this.toChapter(chapter)
      event.preventDefault()

  fullScreen: (message) ->
    log 'fullScreen', message
    @shades.shade()
    @full.find('div').first().html message
    this

  isFullScreen: ->
    @full.is(':visible')

  toChapter: (chapter) ->
    log 'toChapter', chapter
    @n = chapter.n
    this.setStatus "#{chapter.title}"

    @shades.set(chapter.full)
    content = if chapter.full then @full.find('div').first() else @content
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

window.Reader = Reader

