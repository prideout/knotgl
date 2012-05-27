root = exports ? this

aabb = root.utility.aabb

Style =
  WIREFRAME: 0
  SILHOUETTE: 1
  RINGS: 2

# All WebGL rendering and loading takes place here.  Application logic should live elsewhere.
class Renderer
  constructor: (@gl, @width, @height) ->
    @radiansPerSecond = 0.0003
    @transitionMilliseconds = 750
    @spinning = true
    @style = Style.SILHOUETTE
    #@style = Style.WIREFRAME
    #@style = Style.RINGS
    @sketchy = true
    @theta = 0
    @vbos = {}
    @programs = {}
    @selectionIndex = 0
    @hotMouse = false
    @tubeGen = new root.TubeGenerator
    @tubeGen.polygonSides = 10
    @tubeGen.bézierSlices = 3
    @tubeGen.tangentSmoothness = 3
    @compileShaders()
    @gl.disable @gl.CULL_FACE
    glerr("OpenGL error during init") unless @gl.getError() == @gl.NO_ERROR
    @downloadSpines()

  onDownloadComplete: (data) ->
    rawVerts = data['centerlines']
    @spines = new Float32Array(rawVerts)
    @vbos.spines = @gl.createBuffer()
    @gl.bindBuffer @gl.ARRAY_BUFFER, @vbos.spines
    @gl.bufferData @gl.ARRAY_BUFFER, @spines, @gl.STATIC_DRAW
    glerr("Error when trying to create spine VBO") unless @gl.getError() == @gl.NO_ERROR
    toast("downloaded #{@spines.length / 3} verts of spine data")
    @genVertexBuffers()
    @render()

  getCurrentLink: ->
    X = @links[@selectionIndex].id.split '.'
    L = {crossings:X[0], numComponents:X[1], index:X[2]}
    L.numComponents = "" if L.numComponents == 1
    L

  moveSelection: (increment) ->
    currentSelection = @selectionIndex
    nextSelection = currentSelection + increment
    return if nextSelection >= @links.length or nextSelection < 0
    return if nextSelection == currentSelection
    @changeSelection(nextSelection)

  changeSelection: (nextSelection) ->

    currentSelection = @selectionIndex
    @selectionIndex = nextSelection
    root.AnimateNumerals()

    # Note that "iconified" is an animation percentange in [0,1]
    # If the current selection has animation = 0, then start a new transition.
    iconified = @links[currentSelection].iconified
    if iconified is 0
      root.outgoing = new TWEEN.Tween(@links[currentSelection])
        .to({iconified: 1}, 0.5 * @transitionMilliseconds)
        .easing(TWEEN.Easing.Quartic.Out)
      root.incoming = new TWEEN.Tween(@links[nextSelection])
        .to({iconified: 0}, @transitionMilliseconds)
        .easing(TWEEN.Easing.Bounce.Out)
      root.incoming.start()
      root.outgoing.start()

    # If we reached this point, we're interupting an in-progress transition.
    # We instantly snap the currently-incoming element back to the toolbar
    # by forcibly setting its percentage to 1.
    @links[currentSelection].iconified = 1
    @links[nextSelection].iconified = iconified
    root.incoming.replace(@links[nextSelection])

  downloadSpines: ->
    worker = new Worker 'js/downloader.js'
    worker.renderer = this
    worker.onmessage = (response) -> @renderer.onDownloadComplete(response.data)
    worker.postMessage(document.URL + 'data/centerlines.bin')

  compileShaders: ->
    for name, metadata of root.shaders
      continue if name == "source"
      [vs, fs] = metadata.keys
      @programs[name] = @compileProgram vs, fs, metadata.attribs, metadata.uniforms

  render: ->

    # Request the next render cycle on vertical refresh (vsync).
    r = -> root.renderer.render()
    window.requestAnimationFrame(r, $("canvas").get(0))

    # Update all the tweening workers for snazzy animations and whatnot.
    TWEEN.update()

    # Update the Alexander-Briggs labels unless they're collapse-animating.
    root.UpdateLabels() if root.UpdateLabels?

    # The HTML/CSS layer can mark the mouse as hot (window.mouse.hot),
    # or the coffeescript logic can make it hot (this.hotMouse).
    cursor = if @hotMouse or window.mouse.hot then 'pointer' else ''
    $('#rightpage').css({'cursor' : cursor})
    $('#leftpage').css({'cursor' : cursor})

    # Update the spinning animation.
    currentTime = new Date().getTime()
    if @previousTime?
      elapsed = currentTime - @previousTime
      @theta += @radiansPerSecond * elapsed if @spinning
    @previousTime = currentTime

    # Adjust the camera and compute various transforms.
    @projection = mat4.perspective(fov = 45, aspect = @width/@height, near = 5, far = 90)
    view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])
    model = mat4.create()
    @modelview = mat4.create()
    mat4.identity(model)
    mat4.rotateX(model, 3.14/4)
    mat4.rotateY(model, @theta)
    mat4.multiply(view, model, @modelview)
    @normalMatrix = mat4.toMat3(@modelview)

    # This is where I'd normally do a glClear, doesn't seem necessary in WebGL (?)
    #@gl.clearColor(1,0,0,1)
    #@gl.clear(@gl.COLOR_BUFFER_BIT)

    # Draw each knot in its respective viewport
    @updateViewports()
    @renderKnot(knot, link) for knot in link for link in @links
    glerr "Render" unless @gl.getError() == @gl.NO_ERROR

  # Annotates each link with 'iconBox' and 'centralBox', which are aabb objects.
  # If a transition animation is underway, centralBox is an interpolated result.
  updateViewports: ->
    w = tileWidth = @width / @links.length
    h = tileHeight = tileWidth * @height / @width
    y = @height - tileHeight / 2
    x = tileWidth / 2
    bigBox = new aabb 0, 0, @width, @height
    mouse = vec2.create([root.mouse.position.x, @height - root.mouse.position.y])
    @hotMouse = false
    for link in @links
      iconBox = aabb.createFromCenter [x,y], [w,h]
      distance = vec2.dist([x,y], mouse)
      radius = h/2
      if distance < radius and link.iconified is 1
        # 'd' is normalized proximity between mouse and icon center
        d = 1 - distance / radius
        maxExpansion = radius / 3
        iconBox.inflate(d*d * maxExpansion)
        @hotMouse = true
      link.iconBox = iconBox
      t = 1-link.iconified
      link.centralBox = aabb.lerp iconBox, bigBox, t
      x = x + w

  click: ->
    return if not @links? or @links.length is 0
    mouse = vec2.create([root.mouse.position.x, @height - root.mouse.position.y])
    for link in @links
      if link.iconBox.contains(mouse[0], mouse[1]) and link.iconified is 1
        @changeSelection(@links.indexOf(link))

  # Shortcut for setting up a vec4 color uniform
  setColor: (loc, c, α) -> @gl.uniform4f(loc, c[0], c[1], c[2], α)

  setViewport: (box, projectionUniform) ->
    box = box.translated(window.pan.x,0)
    entireViewport = new aabb(0, 0, @width, @height)
    clippedBox = aabb.intersect(box, entireViewport)
    if clippedBox.degenerate()
      @gl.viewport(0,0,1,1)
      return
    cropMatrix = aabb.cropMatrix(clippedBox, box)
    proj = mat4.create(@projection)
    mat4.multiply(proj, cropMatrix)
    @gl.uniformMatrix4fv(projectionUniform, false, proj)
    clippedBox.viewport @gl

  renderKnot: (knot, link) ->

    black = [0,0,0]
    gray = [.1,.1,.1]
    alpha = 0.25 + 0.75 * link.iconified

    # Draw the icon
    program = @programs.wireframe
    @gl.useProgram(program)
    @setViewport link.iconBox, program.projection
    @gl.enable(@gl.BLEND)
    @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbos.spines)
    @gl.enableVertexAttribArray(POSITION)
    @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 12, 0)
    @gl.uniformMatrix4fv(program.modelview, false, @modelview)
    @gl.uniform1f(program.scale, @tubeGen.scale)
    @setColor(program.color, black, alpha)
    [startVertex, vertexCount] = knot.centerline
    @gl.enable(@gl.DEPTH_TEST)
    @gl.lineWidth(2)

    # Draw the thick black outer line.
    # Large values of lineWidth causes ugly fin gaps.
    # Redraw with screen-space offsets to achieve extra thickness.
    for x in [-1..1] by 2
      for y in [-1..1] by 2
        @gl.uniform2f(program.offset, x,y)
        @gl.uniform1f(program.depthOffset, 0)
        @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)

    # Draw a thinner center line down the spine for added depth.
    @gl.enable(@gl.BLEND)
    @gl.lineWidth(2)
    @setColor(program.color, knot.color, alpha)
    @gl.uniform2f(program.offset, 0,0)
    @gl.uniform1f(program.depthOffset, -0.5)
    @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)
    @gl.disableVertexAttribArray(POSITION)

    # Draw the solid knot
    program = @programs.solidmesh
    @gl.enable(@gl.DEPTH_TEST)
    @gl.useProgram(program)
    @setViewport link.centralBox, program.projection
    @setColor(program.color, knot.color, 1)
    @gl.uniformMatrix4fv(program.modelview, false, @modelview)
    @gl.uniformMatrix3fv(program.normalmatrix, false, @normalMatrix)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, knot.tube)
    @gl.enableVertexAttribArray(POSITION)
    @gl.enableVertexAttribArray(NORMAL)
    @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
    @gl.vertexAttribPointer(NORMAL, 3, @gl.FLOAT, false, stride = 24, offset = 12)
    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, knot.triangles)
    if @style == Style.SILHOUETTE
      @gl.enable(@gl.POLYGON_OFFSET_FILL)
      @gl.polygonOffset(-1,12)
    @gl.drawElements(@gl.TRIANGLES, knot.triangles.count, @gl.UNSIGNED_SHORT, 0)
    @gl.disableVertexAttribArray(POSITION)
    @gl.disableVertexAttribArray(NORMAL)
    @gl.disable(@gl.POLYGON_OFFSET_FILL)

    # Draw the wireframe
    @gl.enable(@gl.BLEND)
    @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
    program = @programs.wireframe
    @gl.useProgram(program)
    @setViewport link.centralBox, program.projection
    @gl.uniformMatrix4fv(program.modelview, false, @modelview)
    @gl.uniform1f(program.scale, 1)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, knot.tube)
    @gl.enableVertexAttribArray(POSITION)
    @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, knot.wireframe)
    if @style == Style.WIREFRAME
      @gl.lineWidth(1)
      @gl.uniform1f(program.depthOffset, -0.01)
      @setColor(program.color, black, 0.75)
      @gl.drawElements(@gl.LINES, knot.wireframe.count, @gl.UNSIGNED_SHORT, 0)
    else if @style == Style.RINGS
      @gl.lineWidth(1)
      @gl.uniform1f(program.depthOffset, -0.01)
      @setColor(program.color, black, 0.75)
      @gl.drawElements(@gl.LINES, knot.wireframe.count/2, @gl.UNSIGNED_SHORT, knot.wireframe.count)
    else
      @gl.lineWidth(2)
      @gl.uniform1f(program.depthOffset, 0.01)
      @setColor(program.color, black, 1)
      @gl.drawElements(@gl.LINES, knot.wireframe.count, @gl.UNSIGNED_SHORT, 0)
      if @sketchy
        @gl.lineWidth(1)
        @setColor(program.color, gray, 1)
        @gl.uniform1f(program.depthOffset, -0.01)
        @gl.drawElements(@gl.LINES, knot.wireframe.count/2, @gl.UNSIGNED_SHORT, knot.wireframe.count)

    @gl.disableVertexAttribArray(POSITION)

  # Returns a list of 'ranges' where each range is an [index, count] pair
  # The required [0] at the end seems like a coffeescript bug but I'm not sure.
  getLink: (id) -> (x[1..] for x in root.links when x[0] is id)[0]

  genVertexBuffers: ->
    tableRow = "7.2.3 7.2.4 7.2.5 7.2.6 7.2.7 7.2.8 8.2.1 8.2.2 8.2.3"
    @links = []
    for id in tableRow.split(' ')
      knots = (@tessKnot(component) for component in @getLink(id))
      knots[0].color = [1,1,1,0.75]
      knots[1].color = [0.25,0.5,1,0.75] if knots.length > 1
      knots[2].color = [1,0.5,0.25,0.75] if knots.length > 2
      knots.iconified = 1
      knots.id = id
      @links.push(knots)
    @links[0].iconified = 0
    root.UpdateLabels()

  # Tessellate the given knot
  tessKnot: (component) ->

    # Perform Bézier interpolation
    byteOffset = component[0] * 3 * 4
    numFloats = component[1] * 3
    segmentData = @spines.subarray(component[0] * 3, component[0] * 3 + component[1] * 3)
    centerline = @tubeGen.getKnotPath(segmentData)

    # Create a positions buffer for a swept octagon
    rawBuffer = @tubeGen.generateTube(centerline)
    vbo = @gl.createBuffer()
    @gl.bindBuffer(@gl.ARRAY_BUFFER, vbo)
    @gl.bufferData(@gl.ARRAY_BUFFER, rawBuffer, @gl.STATIC_DRAW)
    console.log "Tube positions has #{rawBuffer.length/3} verts."
    tube = vbo

    # Create the index buffer for the tube wireframe
    # TODO This can be re-used from one knot to another
    polygonCount = centerline.length / 3 - 1
    sides = @tubeGen.polygonSides
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
    vbo = @gl.createBuffer()
    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbo)
    @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, rawBuffer, @gl.STATIC_DRAW)
    wireframe = vbo
    wireframe.count = rawBuffer.length
    console.log "Tube wireframe has #{rawBuffer.length} indices for #{sides} sides and #{centerline.length/3-1} polygons."

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
    vbo = @gl.createBuffer()
    @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbo)
    @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, rawBuffer, @gl.STATIC_DRAW)
    triangles = vbo
    triangles.count = rawBuffer.length

    # Return metadata
    knot =
      centerline: component
      tube: tube
      wireframe: wireframe
      triangles: triangles

  # Compile and link the given shader strings and metadata
  compileProgram: (vName, fName, attribs, uniforms) ->

    compileShader = (gl, name, handle) ->
      gl.compileShader handle
      status = gl.getShaderParameter(handle, gl.COMPILE_STATUS)
      $.gritter.add {title: "GLSL Error: #{name}", text: gl.getShaderInfoLog(handle)} unless status

    # Compile vertex shader
    vSource = root.shaders.source[vName]
    vShader = @gl.createShader(@gl.VERTEX_SHADER)
    @gl.shaderSource vShader, vSource
    compileShader @gl, vName, vShader

    # Compile fragment shader
    fSource = root.shaders.source[fName]
    fShader = @gl.createShader(@gl.FRAGMENT_SHADER)
    @gl.shaderSource fShader, fSource
    compileShader @gl, fName, fShader

    # Link 'em
    program = @gl.createProgram()
    @gl.attachShader program, vShader
    @gl.attachShader program, fShader
    @gl.bindAttribLocation(program, value, key) for key, value of attribs
    @gl.linkProgram program
    status = @gl.getProgramParameter(program, @gl.LINK_STATUS)
    glerr("Could not link #{vName} with #{fName}") unless status
    program[value] = @gl.getUniformLocation(program, key) for key, value of uniforms
    program

root.Renderer = Renderer
[sin, cos, pow, abs] = (Math[f] for f in "sin cos pow abs".split(' '))
dot = vec3.dot
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)
TWOPI = 2 * Math.PI
