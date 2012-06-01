###
#
# This worker file needs to be concatenated with TubeGenerator and gl-matrix.
# It also needs to be built with the --bare flag so that it can access TubeGenerator. <--- IS THIS TRUE?
# Type "cake worker" to ask the cakefile to do all this work.
#
# Here's our little JSON-based communication protocol.  Eveything in the left column
# is an object property except 'type', which tells you which direction(s) the message
# should travel in.
#
# ---------------------------
#   command: 'download'
#      type: client -> worker
#       url: <STRING>
# ---------------------------
#   command: 'tessellate'
#      type: client -> worker
#      link: <Array of RANGE>
#            where RANGE = [INTEGER, INTEGER]
# ---------------------------
#   command: 'mesh'
#      type: worker -> client
#      tube: <Float32Array>
# wireframe: <Uint16Array>
# triangles: <Uint16Array>
# ---------------------------
#     command: 'centerlines' <----------- TEMPORARY MESSAGE.  TO BE REMOVED.
#        type: worker -> client
# centerlines: <ArrayBuffer>
# ---------------------------
#
###

tubeGen = null
initialized = null

download = (url) ->
  xhr = new XMLHttpRequest()
  xhr.open "GET", url, false
  xhr.overrideMimeType "text/plain; charset=x-user-defined"
  hasResponseType = "responseType" of xhr
  xhr.responseType = "arraybuffer" if hasResponseType
  xhr.send null
  return null if xhr.status isnt 200
  if hasResponseType then xhr.response else xhr.mozResponseArrayBuffer

initialize = ->
  tubeGen = new TubeGenerator
  tubeGen.polygonSides = 10
  tubeGen.bézierSlices = 3
  tubeGen.tangentSmoothness = 3
  initialized = true

@onmessage = (e) ->
  initialize() if not initialized?
  msg = e.data
  if msg.command is 'download'
    centerlines = download msg.url
    response = centerlines : centerlines
    @postMessage response
