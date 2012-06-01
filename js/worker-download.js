// Generated by CoffeeScript 1.3.1
(function() {
  var download;

  download = function(url) {
    var hasResponseType, xhr;
    xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.overrideMimeType("text/plain; charset=x-user-defined");
    hasResponseType = "responseType" in xhr;
    if (hasResponseType) {
      xhr.responseType = "arraybuffer";
    }
    xhr.send(null);
    if (xhr.status !== 200) {
      return null;
    }
    if (hasResponseType) {
      return xhr.response;
    } else {
      return xhr.mozResponseArrayBuffer;
    }
  };

  this.onmessage = function(e) {
    var centerlines, response;
    centerlines = download(e.data);
    response = {
      centerlines: centerlines
    };
    return this.postMessage(response);
  };

}).call(this);
