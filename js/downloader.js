function download(url)
{
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.overrideMimeType("text/plain; charset=x-user-defined");
    var hasResponseType = "responseType" in xhr;
    if (hasResponseType) xhr.responseType = "arraybuffer";
    xhr.send(null);
    if (xhr.status != 200) console.log('Problem downloading ' + url); /////////// can't call alert from a web worker!
    return hasResponseType ? xhr.response : xhr.mozResponseArrayBuffer;
}
self.onmessage = function(url) {
    var centerlines = download('http://localhost:8000/data/centerlines.bin');
    var response = {
        'centerlines' : centerlines,
    };
    self.postMessage(response);
};
