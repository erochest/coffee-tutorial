
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
    @buffer  = @context.createImageData @width, @height
    this

  # This gets the index in the `ImageData` for position x and y.
  index: (x, y) ->
    4 * (y * @width + x)

  # This gets the value of the current state for the x, y pixel and the color
  # offset.
  get: (x, y, colorOffset) ->
    @buffer.data[this.index(x, y) + colorOffset]

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

# This defines the environment. It uses some arrays of cell objects, which have
# the properties x, y, alive, and count.
class Environment

  constructor: (@width, @height) ->
    @world = []
    @index = {}
    @gen   = 0

  # This clears the world.
  clear: ->
    @world = []
    @index = {}
    @gen   = 0

  # This sets `n` random cells.
  #
  # `n` can be an integer, which is the number of pixels to fill, or a
  # float-point percent in the range [0-1].
  randomFill: (n) ->
    random = (x) -> Math.floor(Math.random() * x)
    width  = @width
    height = @height
    world  = []
    index  = {}

    # If n is a percentage, then get the actual number of cells to fill in.
    count = if Math.floor(n) == 0 then Math.floor(n * width * height) else n

    while count > 0
      i = random width
      j = random height
      key = "#{i}-#{j}"
      if !index[key]?
        cell = [i, j, true, 0]
        index[key] = cell
        world.push cell
        count--

    @world = world
    @index = index
    @gen   = 0
    this

  # This clears the world and adds a blinker to the middle of the screen.
  blinker: ->
    world = []
    index = {}

    midX = Math.floor(@width  / 2)
    midY = Math.floor(@height / 2)

    for dy in [-1, 0, +1]
      y = midY + dy
      cell = [midX, y, true, 0]
      world.push cell
      index["#{midX}-#{y}"] = cell

    @world = world
    @index = index
    @gen   = 0
    this

  # This updates the state for the next generation.
  update: ->
    width   = @width
    height  = @height
    index   = {}
    next    = []

    # First, iterate over the current living cells.
    population = @world.length
    c = 0
    while c < population
      cell = @world[c]
      cellX = cell[0]
      cellY = cell[1]

      # Now iterate over the x offsets.
      i = 0
      while i < 3
        x = cellX + i - 1

        # And the y offsets.
        j = 0
        while j < 3
          y = cellY + j - 1

          # Don't process if we're looking at the current cell or if we're off
          # the screen.
          if ((i != 1 || j != 1) && (0 <= x < width && 0 <= y < height))
            # Increment the count for existing next cells or create a new cell.
            key = "#{x}-#{y}"
            if index[key]?
              index[key][3]++
            else
              newCell = [x, y, Boolean(@index[key]?[2]), 1]
              index[key] = newCell
              next.push newCell

          j++
        i++
      c++

    world = (cell for cell in next when this.alive cell)
    cell[2] = true for cell in world
    @world = world
    @index = {}
    for cell in world
      @index["#{cell[0]}-#{cell[1]}"] = cell

    @gen++

  # These are the rules for whether a cell lives into the next generation.
  alive: (cell) ->
    alive = cell[2]
    count = cell[3]
    ((!alive && count == 3) ||
      (alive && (count == 2 || count == 3)))

# This manages the world.
class Life
  cellSize: 1
  background: 'black'

  # This takes the jQuery DOM objects for the world and the status `<div>`.
  constructor: (@env, @status) ->
    @buffer = new BufferedCanvas @env
    @world  = new Environment @buffer.width, @buffer.height
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
    @world.randomFill n
    this.draw()

  # This runs one generation of the loop and requests the animation frame for
  # the next generation.
  run: (step=false) ->
    @start = new Date() unless @start?
    @startGen = @world.gen unless @startGen?

    @world.update()
    this.draw()

    this.updateStatus "Generation: #{ @world.gen }"

    # Don't request a new animation frame if we're not running.
    if not step && not @stopped
      requestAnimFrame => this.run()
    else
      end = new Date()
      elapsed = (end.getTime() - @start.getTime()) / 1000
      this.updateStatus "Generation: #{ @world.gen } | #{ (@world.gen  - @startGen) / elapsed } generations per second."
      @start = null
      @startGen = null

  # This clears the screen and adds a blinker to the middle of the screen.
  blinker: ->
    @world.blinker()
    this.draw()

  # This clears the canvas and draws the buffer.
  draw: ->
    world = @world.world
    size  = world.length
    i     = 0
    while i < size
      cell = world[i]
      @buffer.set cell[0], cell[1], 255
      i++

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

