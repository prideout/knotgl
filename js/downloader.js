function download(url)
{
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.overrideMimeType("text/plain; charset=x-user-defined");
    var hasResponseType = "responseType" in xhr;
    if (hasResponseType) xhr.responseType = "arraybuffer";
    xhr.send(null);
    if (xhr.status != 200) alert('Problem downloading ' + url);
    return hasResponseType ? xhr.response : xhr.mozResponseArrayBuffer;
}
self.onmessage = function(request) {
    toast("downloading " + request + "...");
    var centerlines = download("http://github.com/prideout/knot-data/raw/master/" + request);
    var response = {
        'centerlines' : centerlines,
    };
    self.postMessage(response);
};
