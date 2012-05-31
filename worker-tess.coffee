download = (url) ->
    xhr = new XMLHttpRequest()
    xhr.open("GET", url, false)
    xhr.overrideMimeType("text/plain; charset=x-user-defined")
    hasResponseType = "responseType" of xhr
    xhr.responseType = "arraybuffer" if hasResponseType
    xhr.send null
    return null if xhr.status isnt 200
    if hasResponseType then xhr.response else xhr.mozResponseArrayBuffer

@onmessage = (e) ->
    centerlines = download(e.data)
    response = {
        'centerlines' : centerlines,
    }
    @postMessage(response)
