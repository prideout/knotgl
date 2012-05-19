function download(url)
{
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.overrideMimeType("text/plain; charset=x-user-defined");
    var hasResponseType = "responseType" in xhr;
    if (hasResponseType)
        xhr.responseType = "arraybuffer";
    xhr.send(null);
    if (xhr.status != 200)
        return null;
    return hasResponseType ? xhr.response : xhr.mozResponseArrayBuffer;
}

self.onmessage = function(e) {
    var centerlines = download(e.data);
    var response = {
        'centerlines' : centerlines,
    };
    self.postMessage(response);
};
