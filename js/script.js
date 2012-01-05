(function() {

  $(function() {
    var reader;
    reader = new Reader();
    reader.loadBook(window.tutorial);
    return window.reader = reader;
  });

}).call(this);
