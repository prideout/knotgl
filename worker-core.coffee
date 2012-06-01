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
#   command: 'download-spines'
#      type: client -> worker
#       url: <STRING>
# ---------------------------
#   command: 'tessellate-link'
#      type: client -> worker
#        id: <anything>
#      link: <Array of RANGE>
#            where RANGE = [INTEGER, INTEGER]
# ---------------------------
#   command: 'mesh-link'
#      type: worker -> client
#        id: <anything>
#    meshes: <Array of MESH>
#            where MESH =
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
spines = null

@onmessage = (e) ->
  initialize() if not initialized?
  msg = e.data
  switch msg.command
    when 'download-spines'
      rawdata = download msg.url
      spines = new Float32Array rawdata
      response =
        command: 'centerlines'
        centerlines: rawdata
      @postMessage response
    when 'tessellate-link'
      meshes = (tessellate knot for knot in msg.link)
      response =
        command: 'mesh-link'
        id: msg.id
        meshes: meshes
      @postMessage response

initialize = ->
  tubeGen = new TubeGenerator
  tubeGen.polygonSides = 10
  tubeGen.bézierSlices = 3
  tubeGen.tangentSmoothness = 3
  initialized = true

download = (url) ->
  xhr = new XMLHttpRequest()
  xhr.open "GET", url, false
  xhr.overrideMimeType "text/plain; charset=x-user-defined"
  hasResponseType = "responseType" of xhr
  xhr.responseType = "arraybuffer" if hasResponseType
  xhr.send null
  return null if xhr.status isnt 200
  if hasResponseType then xhr.response else xhr.mozResponseArrayBuffer

tessellate = (component) ->

    # Perform Bézier interpolation
    byteOffset = component[0] * 3 * 4
    numFloats = component[1] * 3
    segmentData = spines.subarray(component[0] * 3, component[0] * 3 + component[1] * 3)
    centerline = tubeGen.getKnotPath(segmentData)

    # Create a positions buffer for a swept octagon
    rawBuffer = tubeGen.generateTube(centerline)
    tube = rawBuffer

    # Create the index buffer for the tube wireframe
    # TODO This can be re-used from one knot to another
    polygonCount = centerline.length / 3 - 1
    sides = tubeGen.polygonSides
    lineCount = polygonCount * sides * 2
    rawBuffer = new Uint16Array(lineCount * 2)
    [i, ptr] = [0, 0]
    while i < polygonCount * (sides+1)
      j = 0
      while j < sides
        sweepEdge = rawBuffer.subarray(ptr+2, ptr+4)
        sweepEdge[0] = i+j
        sweepEdge[1] = i+j+sides+1
        [ptr, j] = [ptr+2, j+1]
      i += sides+1
    i = 0
    while i < polygonCount * (sides+1)
      j = 0
      while j < sides
        polygonEdge = rawBuffer.subarray(ptr+0, ptr+2)
        polygonEdge[0] = i+j
        polygonEdge[1] = i+j+1
        [ptr, j] = [ptr+2, j+1]
      i += sides+1
    wireframe = rawBuffer

    # Create the index buffer for the solid tube
    # TODO This can be be re-used from one knot to another
    faceCount = centerline.length/3 * sides * 2
    rawBuffer = new Uint16Array(faceCount * 3)
    [i, ptr, v] = [0, 0, 0]
    while ++i < centerline.length/3
      j = -1
      while ++j < sides
        next = (j + 1) % sides
        tri = rawBuffer.subarray(ptr+0, ptr+3)
        tri[0] = v+next+sides+1
        tri[1] = v+next
        tri[2] = v+j
        tri = rawBuffer.subarray(ptr+3, ptr+6)
        tri[0] = v+j
        tri[1] = v+j+sides+1
        tri[2] = v+next+sides+1
        ptr += 6
      v += sides+1
    triangles = rawBuffer

    # Return metadata
    mesh =
      tube: tube
      wireframe: wireframe
      triangles: triangles
