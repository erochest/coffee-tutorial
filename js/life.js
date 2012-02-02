(function() {
  var BufferedCanvas, Environment, Life, life;

  window.requestAnimFrame = window.requestAnimationFrame || window.webkitRequestAnimationFrame || window.mozRequestAnimationFrame || window.oRequestAnimationFrame || window.msRequestAnimationFrame || function(callback) {
    return window.setTimeout(callback, 1000 / 60);
  };

  BufferedCanvas = (function() {

    function BufferedCanvas(canvas) {
      this.canvas = $(canvas);
      this.reset();
    }

    BufferedCanvas.prototype.reset = function() {
      var canvas;
      canvas = this.canvas[0];
      this.width = this.canvas.width();
      this.height = this.canvas.height();
      canvas.width = this.width;
      canvas.height = this.height;
      this.context = canvas.getContext('2d');
      return this.resetBuffers();
    };

    BufferedCanvas.prototype.resetBuffers = function() {
      this.buffer = this.context.createImageData(this.width, this.height);
      return this;
    };

    BufferedCanvas.prototype.index = function(x, y) {
      return 4 * (y * this.width + x);
    };

    BufferedCanvas.prototype.get = function(x, y, colorOffset) {
      return this.buffer.data[this.index(x, y) + colorOffset];
    };

    BufferedCanvas.prototype.set = function(x, y, red, green, blue, alpha) {
      var i;
      if (red == null) red = 0;
      if (green == null) green = 0;
      if (blue == null) blue = 0;
      if (alpha == null) alpha = 255;
      i = this.index(x, y);
      this.buffer.data[i + 0] = red;
      this.buffer.data[i + 1] = green;
      this.buffer.data[i + 2] = blue;
      this.buffer.data[i + 3] = alpha;
      return this;
    };

    BufferedCanvas.prototype.unset = function(x, y) {
      this.set(x, y, 0, 0, 0, 0);
      return this;
    };

    BufferedCanvas.prototype.draw = function() {
      this.context.putImageData(this.buffer, 0, 0);
      return this.resetBuffers();
    };

    BufferedCanvas.prototype.clear = function() {
      var canvas;
      canvas = this.canvas[0];
      canvas.width = canvas.width;
      return this;
    };

    return BufferedCanvas;

  })();

  Environment = (function() {

    function Environment(width, height) {
      this.width = width;
      this.height = height;
      this.world = [];
      this.index = {};
      this.gen = 0;
    }

    Environment.prototype.clear = function() {
      this.world = [];
      this.index = {};
      return this.gen = 0;
    };

    Environment.prototype.randomFill = function(n) {
      var cell, count, height, i, index, j, key, random, width, world;
      random = function(x) {
        return Math.floor(Math.random() * x);
      };
      width = this.width;
      height = this.height;
      world = [];
      index = {};
      count = Math.floor(n) === 0 ? Math.floor(n * width * height) : n;
      while (count > 0) {
        i = random(width);
        j = random(height);
        key = "" + i + "-" + j;
        if (!(index[key] != null)) {
          cell = [i, j, true, 0];
          index[key] = cell;
          world.push(cell);
          count--;
        }
      }
      this.world = world;
      this.index = index;
      this.gen = 0;
      return this;
    };

    Environment.prototype.blinker = function() {
      var cell, dy, index, midX, midY, world, y, _i, _len, _ref;
      world = [];
      index = {};
      midX = Math.floor(this.width / 2);
      midY = Math.floor(this.height / 2);
      _ref = [-1, 0, +1];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dy = _ref[_i];
        y = midY + dy;
        cell = [midX, y, true, 0];
        world.push(cell);
        index["" + midX + "-" + y] = cell;
      }
      this.world = world;
      this.index = index;
      this.gen = 0;
      return this;
    };

    Environment.prototype.update = function() {
      var c, cell, cellX, cellY, height, i, index, j, key, newCell, next, population, width, world, x, y, _i, _j, _len, _len2, _ref;
      width = this.width;
      height = this.height;
      index = {};
      next = [];
      population = this.world.length;
      c = 0;
      while (c < population) {
        cell = this.world[c];
        cellX = cell[0];
        cellY = cell[1];
        i = 0;
        while (i < 3) {
          x = cellX + i - 1;
          j = 0;
          while (j < 3) {
            y = cellY + j - 1;
            if ((i !== 1 || j !== 1) && ((0 <= x && x < width) && (0 <= y && y < height))) {
              key = "" + x + "-" + y;
              if (index[key] != null) {
                index[key][3]++;
              } else {
                newCell = [x, y, Boolean((_ref = this.index[key]) != null ? _ref[2] : void 0), 1];
                index[key] = newCell;
                next.push(newCell);
              }
            }
            j++;
          }
          i++;
        }
        c++;
      }
      world = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = next.length; _i < _len; _i++) {
          cell = next[_i];
          if (this.alive(cell)) _results.push(cell);
        }
        return _results;
      }).call(this);
      for (_i = 0, _len = world.length; _i < _len; _i++) {
        cell = world[_i];
        cell[2] = true;
      }
      this.world = world;
      this.index = {};
      for (_j = 0, _len2 = world.length; _j < _len2; _j++) {
        cell = world[_j];
        this.index["" + cell[0] + "-" + cell[1]] = cell;
      }
      return this.gen++;
    };

    Environment.prototype.alive = function(cell) {
      var alive, count;
      alive = cell[2];
      count = cell[3];
      return (!alive && count === 3) || (alive && (count === 2 || count === 3));
    };

    return Environment;

  })();

  Life = (function() {

    Life.prototype.cellSize = 1;

    Life.prototype.background = 'black';

    function Life(env, status) {
      var _this = this;
      this.env = env;
      this.status = status;
      this.buffer = new BufferedCanvas(this.env);
      this.world = new Environment(this.buffer.width, this.buffer.height);
      this.updateStatus("Conway's Life");
      this.stopped = false;
      this.env.click(function() {
        _this.stopped = !_this.stopped;
        if (!_this.stopped) return _this.run();
      });
    }

    Life.prototype.randomFill = function(n) {
      this.world.randomFill(n);
      return this.draw();
    };

    Life.prototype.run = function(step) {
      var elapsed, end,
        _this = this;
      if (step == null) step = false;
      if (this.start == null) this.start = new Date();
      if (this.startGen == null) this.startGen = this.world.gen;
      this.world.update();
      this.draw();
      this.updateStatus("Generation: " + this.world.gen);
      if (!step && !this.stopped) {
        return requestAnimFrame(function() {
          return _this.run();
        });
      } else {
        end = new Date();
        elapsed = (end.getTime() - this.start.getTime()) / 1000;
        this.updateStatus("Generation: " + this.world.gen + " | " + ((this.world.gen - this.startGen) / elapsed) + " generations per second.");
        this.start = null;
        return this.startGen = null;
      }
    };

    Life.prototype.blinker = function() {
      this.world.blinker();
      return this.draw();
    };

    Life.prototype.draw = function() {
      var cell, i, size, world;
      world = this.world.world;
      size = world.length;
      i = 0;
      while (i < size) {
        cell = world[i];
        this.buffer.set(cell[0], cell[1], 255);
        i++;
      }
      return this.buffer.draw();
    };

    Life.prototype.clear = function() {
      return this.buffer.clear();
    };

    Life.prototype.updateStatus = function(msg) {
      return this.status.html(msg);
    };

    return Life;

  })();

  life = new Life($('#sandbox'), $('#status'));

  life.randomFill(0.25);

  life.run();

  window.life = life;

}).call(this);
