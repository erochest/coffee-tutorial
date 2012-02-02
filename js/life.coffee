
window.requestAnimFrame =
  window.requestAnimationFrame       ||
  window.webkitRequestAnimationFrame ||
  window.mozRequestAnimationFrame    ||
  window.oRequestAnimationFrame      ||
  window.msRequestAnimationFrame     || 
  (callback) -> window.setTimeout callback, 1000/60

# We're using an explicit double buffer here. One is for the current state of
# the world, the other is for the next state. They're kept in `ImageData`
# objects generated directly from the canvas, and they're switched using the
# 'draw' method.
#
# Currently, this assumes that the abstract grid maps directly to the pixel
# grid.
#
# This also manages the canvas and its context. The only long-term reference to
# the context is held by this class.

class BufferedCanvas

  # This initializes the `BufferedCanvas` with the `<canvas>` DOM object.
  constructor: (canvas) ->
    @canvas = $ canvas
    this.reset()

  # This resets the current and buffer after a change from outside this
  # `BufferedCanvas`. Any changes in `buffer` will be thrown away. This also
  # clears the canvas.
  reset: ->
    canvas = @canvas[0]

    # Get the current height of the canvas.
    @width   = @canvas.width()
    @height  = @canvas.height()

    # Set the DOM's height and width and get a new context.
    canvas.width  = @width
    canvas.height = @height
    @context      = canvas.getContext '2d'

    # Create the buffers from the context. Also supports method chaining.
    this.resetBuffers()

  # Just resets the buffers.
  resetBuffers: ->
    @current = @context.getImageData 0, 0, @width, @height
    @buffer  = @context.createImageData @current
    this

  # This gets the index in the `ImageData` for position x and y.
  index: (x, y) ->
    4 * (y * @width + x)

  # This gets the value of the current state for the x, y pixel and the color
  # offset.
  get: (x, y, colorOffset) ->
    @current.data[this.index(x, y) + colorOffset]

  # This is like `get`, only it queries the buffer.
  getBuffer: (x, y, colorOffset) ->
    i = this.index x, y
    @buffer.data[i + colorOffset]

  # This sets the value for the next state.
  set: (x, y, red=0, green=0, blue=0, alpha=255) ->
    i = this.index x, y
    @buffer.data[i + 0] = red
    @buffer.data[i + 1] = green
    @buffer.data[i + 2] = blue
    @buffer.data[i + 3] = alpha

    # Method chaining
    this

  # This unsets the value for the next state. That is, it sets it to
  # transparent black.
  unset: (x, y) ->
    this.set x, y, 0, 0, 0, 0
    this

  # This swaps out the buffer and makes the @buffer the current.
  draw: ->
    @context.putImageData @buffer, 0, 0
    this.resetBuffers()

  # This clears the canvas.
  clear: ->
    canvas = @canvas[0]
    canvas.width = canvas.width
    this

# This manages the world.
class Life
  cellSize: 1
  background: 'black'

  # This takes the jQuery DOM objects for the world and the status `<div>`.
  constructor: (@env, @status) ->
    @buffer = new BufferedCanvas @env
    @gen = 0
    this.updateStatus "Conway's Life"

    # This toggles processing when you click on the canvas.
    @stopped = false
    @env.click =>
      @stopped = not @stopped
      this.run() unless @stopped

  # This sets `n` random cells and draws the buffer.
  #
  # `n` can be an integer, which is the number of pixels to fill, or a
  # float-point percent in the range [0-1].
  randomFill: (n) ->
    random = (x) -> Math.floor(Math.random() * x)

    @buffer.reset()
    width  = @buffer.width
    height = @buffer.height

    # If n is a percentage, then get the actual number of cells to fill in.
    count = if Math.floor(n) == 0 then Math.floor(n * width * height) else n

    while count > 0
      i = random width
      j = random height
      if @buffer.getBuffer(i, j, 0) == 0
        @buffer.set i, j, 255
        count -= 1

    this.draw()

  # This runs one generation of the loop and requests the animation frame for
  # the next generation.
  run: ->
    this.update()
    this.draw()

    @gen += 1
    this.updateStatus "Generation: #{ @gen }"

    # Don't request a new animation frame if we're not running.
    if not @stopped
      requestAnimFrame => this.run()

  # This clears the screen and adds a blinker to the middle of the screen.
  blinker: ->
    @buffer.reset()

    midX = Math.floor(@buffer.width  / 2)
    midY = Math.floor(@buffer.height / 2)

    @buffer
      .set(midX, midY - 1, 255)
      .set(midX, midY + 0, 255)
      .set(midX, midY + 1, 255)

    @buffer.draw()
    [midX, midY]

  outline: ->
    @buffer.reset()

    width  = @buffer.width
    height = @buffer.height

    count = 0
    x = 0
    while x < width
      @buffer
        .set(x, 0, 255)
        .set(x, @buffer.height - 1, 255)
      x++
      count += 2
    y = 0
    while y < height
      @buffer
        .set(0, y, 255)
        .set(@buffer.width - 1, y, 255)
      y++
      count += 2

    log @buffer.width, @buffer.height, count
    this.draw()

  outlineRect: ->
    @buffer.reset()

    @buffer.context.strokeStyle = 'maroon'

    bounds = [0, 0, @buffer.width - 1, @buffer.height - 1]
    log bounds...
    @buffer.context.strokeRect bounds...

  # This updates the state for the next generation buffer.
  update: ->
    width  = @buffer.width
    height = @buffer.height

    i = 0
    while i < width
      j = 0
      while j < height
        if this.next(i, j)
          @buffer.set(i, j, 255)
        j++
      i++

  # This looks at the buffer and determines whether the given cell should be
  # turned on or off for the next generation. It returns a bool, with `true`
  # equal to on.
  next: (i, j) ->
    count  = 0
    width  = @buffer.width
    height = @buffer.height

    dx = 0
    while dx < 3
      dy = 0
      m = i + dx - 1
      while dy < 3
        n = j + dy - 1

        # This says:
        # * m and n are both in bounds and
        # * we're not looking at the current cell and
        # * the cell we are looking at is active.
        if (0 <= m < width && 0 <= n < height &&
            ! (i == m && j == n) &&
            this.active m, n)
          count += 1

        dy++
      dx++

    switch count
      when 2 then this.active i, j
      when 3 then true
      else false

  # This returns true if the given place is active.
  active: (x, y) ->
    @buffer.get(x, y, 0) > 0

  # This clears the canvas and draws the buffer.
  draw: ->
    @buffer.draw()

  # This clears the canvas.
  clear: ->
    @buffer.clear()

  # This updates the status message.
  updateStatus: (msg) ->
    @status.html msg


life = new Life $('#sandbox'), $('#status')
life.randomFill 0.25
# life.blinker()
life.run()

window.life = life

