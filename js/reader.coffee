
# TODO:
# ToC.
# Storing code, bookmarks between pages and sessions.

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

    @full.hide()

  # This makes an AJAX request to load @tocUrl and displays it.
  loadToC: (toc) ->
    log 'loadToC', toc
    @toc = toc
    @title.html(toc.title)

    links = (this.chapterLink(chapter) for chapter in toc.chapters)
    this.populateToC(links)
    this.wireToCEvents()

    this.fullScreen(toc.welcome) if toc.welcome?
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

  # This actually takes care of wiring up the event.
  toChapterEvent: (element, chapter) ->
    $(element).click (event) =>
      this.toChapter(chapter)
      event.preventDefault()

  # These are repeated from the Compass/Susy-generated CSS. Yech. Very not DRY.
  expandContent: ->
    log 'expandContent'
    @main
      .find('#repl').add('#contentbar')
      .fadeOut 'normal', =>
        @main.find('#fullcontent').fadeIn()
    this

  retractContent: ->
    log 'retractContent'
    @main
      .find('#fullcontent')
      .fadeOut 'normal', =>
        @main.find('#repl').add('#contentbar').fadeIn()
    this

  fullScreen: (message) ->
    log 'fullScreen', message
    this.expandContent()
    @full.find('div').first().html message
    this

  toChapter: (chapter) ->
    log 'toChapter', chapter
    @n = chapter.n
    this.setStatus "#{chapter.title} &mdash; #{@n}"
    this

  setStatus: (message) ->
    log 'setStatus', message
    @status.html(message)
    this

window.Reader = Reader

