(function() {

  $(function() {
    var reader;
    reader = new Reader();
    reader.loadToC(window.tutorial);
    return window.reader = reader;
  });

}).call(this);
