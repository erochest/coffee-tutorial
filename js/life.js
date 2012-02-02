(function() {
  var BufferedCanvas, Life, life;

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
      this.current = this.context.getImageData(0, 0, this.width, this.height);
      this.buffer = this.context.createImageData(this.current);
      return this;
    };

    BufferedCanvas.prototype.index = function(x, y) {
      return 4 * (y * this.width + x);
    };

    BufferedCanvas.prototype.get = function(x, y, colorOffset) {
      var i;
      i = this.index(x, y);
      return this.current.data[i + colorOffset];
    };

    BufferedCanvas.prototype.getBuffer = function(x, y, colorOffset) {
      var i;
      i = this.index(x, y);
      return this.buffer.data[i + colorOffset];
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

  Life = (function() {

    Life.prototype.cellSize = 1;

    Life.prototype.background = 'black';

    function Life(env, status) {
      var _this = this;
      this.env = env;
      this.status = status;
      this.buffer = new BufferedCanvas(this.env);
      this.gen = 0;
      this.updateStatus("Conway's Life");
      this.stopped = false;
      this.env.click(function() {
        _this.stopped = !_this.stopped;
        if (!_this.stopped) return _this.run();
      });
    }

    Life.prototype.randomFill = function(n) {
      var count, height, i, j, random, width;
      random = function(x) {
        return Math.floor(Math.random() * x);
      };
      this.buffer.reset();
      width = this.buffer.width;
      height = this.buffer.height;
      count = Math.floor(n) === 0 ? Math.floor(n * width * height) : n;
      while (count > 0) {
        i = random(width);
        j = random(height);
        if (this.buffer.getBuffer(i, j, 0) === 0) {
          this.buffer.set(i, j, 255);
          count -= 1;
        }
      }
      return this.draw();
    };

    Life.prototype.run = function() {
      var _this = this;
      this.update();
      this.draw();
      this.gen += 1;
      this.updateStatus("Generation: " + this.gen);
      if (!this.stopped) {
        return requestAnimFrame(function() {
          return _this.run();
        });
      }
    };

    Life.prototype.blinker = function() {
      var midX, midY;
      this.buffer.reset();
      midX = Math.floor(this.buffer.width / 2);
      midY = Math.floor(this.buffer.height / 2);
      this.buffer.set(midX, midY - 1, 255).set(midX, midY + 0, 255).set(midX, midY + 1, 255);
      this.buffer.draw();
      return [midX, midY];
    };

    Life.prototype.outline = function() {
      var count, x, y, _ref, _ref2;
      this.buffer.reset();
      count = 0;
      for (x = 0, _ref = this.buffer.width - 1; 0 <= _ref ? x <= _ref : x >= _ref; 0 <= _ref ? x++ : x--) {
        this.buffer.set(x, 0, 255).set(x, this.buffer.height - 1, 255);
        count += 2;
      }
      for (y = 0, _ref2 = this.buffer.height - 1; 0 <= _ref2 ? y <= _ref2 : y >= _ref2; 0 <= _ref2 ? y++ : y--) {
        this.buffer.set(0, y, 255).set(this.buffer.width - 1, y, 255);
        count += 2;
      }
      log(this.buffer.width, this.buffer.height, count);
      return this.draw();
    };

    Life.prototype.outlineRect = function() {
      var bounds, _ref;
      this.buffer.reset();
      this.buffer.context.strokeStyle = 'maroon';
      bounds = [0, 0, this.buffer.width - 1, this.buffer.height - 1];
      log.apply(null, bounds);
      return (_ref = this.buffer.context).strokeRect.apply(_ref, bounds);
    };

    Life.prototype.update = function() {
      var count, height, i, j, total, width, _results;
      total = 0;
      count = 0;
      width = this.buffer.width - 1;
      height = this.buffer.height - 1;
      _results = [];
      for (i = 0; 0 <= width ? i <= width : i >= width; 0 <= width ? i++ : i--) {
        _results.push((function() {
          var _results2;
          _results2 = [];
          for (j = 0; 0 <= height ? j <= height : j >= height; 0 <= height ? j++ : j--) {
            total += 1;
            if (this.next(i, j)) {
              _results2.push(this.buffer.set(i, j, 255));
            } else {
              _results2.push(void 0);
            }
          }
          return _results2;
        }).call(this));
      }
      return _results;
    };

    Life.prototype.next = function(i, j) {
      var count, height, m, n, width, _ref, _ref2, _ref3, _ref4;
      count = 0;
      width = this.buffer.width;
      height = this.buffer.height;
      for (m = _ref = i - 1, _ref2 = i + 1; _ref <= _ref2 ? m <= _ref2 : m >= _ref2; _ref <= _ref2 ? m++ : m--) {
        for (n = _ref3 = j - 1, _ref4 = j + 1; _ref3 <= _ref4 ? n <= _ref4 : n >= _ref4; _ref3 <= _ref4 ? n++ : n--) {
          if ((0 <= m && m < width) && (0 <= n && n < height) && !(i === m && j === n) && this.active(m, n)) {
            count += 1;
          }
        }
      }
      switch (count) {
        case 2:
          return this.active(i, j);
        case 3:
          return true;
        default:
          return false;
      }
    };

    Life.prototype.active = function(x, y) {
      return this.buffer.get(x, y, 0) > 0;
    };

    Life.prototype.draw = function() {
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
