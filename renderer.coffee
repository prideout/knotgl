root = exports ? this

# All WebGL rendering and loading takes place here.  Application logic should live elsewhere.
class Renderer

  constructor: (@gl, @width, @height) ->
    @radiansPerSecond = 0.0003
    @transitionMilliseconds = 750
    @style = Style.SILHOUETTE
    @sketchy = true
    @vbos = {}
    @programs = {}
    @selectedColumn = 0
    @selectedRow = 9
    @hotMouse = false
    @tubeGen = new root.TubeGenerator
    @tubeGen.polygonSides = 10
    @tubeGen.bézierSlices = 3
    @tubeGen.tangentSmoothness = 3
    @compileShaders()
    @gl.disable @gl.CULL_FACE
    glerr("OpenGL error during init") unless @gl.getError() == @gl.NO_ERROR
    @parseMetadata()
    @downloadSpineData()

  # Read the metadata table (see knots.coffee) and arrange it into a "links" array.
  # Each "link" is an annotated array of "knot" objects.
  # Link properties: id, iconified, iconBox, centralBox, tableBox.
  # Knot properties: range, vbos, color.
  # Each "range" is an [index, count] pair that defines a window into the raw spine data.
  parseMetadata: ->
    KnotColors = [
      [0.5,0.75,1,0.75]
      [0.9,1,0.9,0.75]
      [1,0.75,0.5,0.75]
    ]
    Table = [
      '0.1 3.1 4.1 5.1 5.2 6.1 6.2 6.3 7.1'
      '7.2 7.3 7.4 7.5 7.6 7.7 8.1 8.2 8.3'
      ("8.#{i}" for i in [4..12]).join(' ')
      ("8.#{i}" for i in [13..21]).join(' ')
      ("9.#{i}" for i in [1..9]).join(' ')
      ("9.#{i}" for i in [10..18]).join(' ')
      ("9.#{i}" for i in [19..27]).join(' ')
      ("9.#{i}" for i in [28..36]).join(' ')
      '0.2.1 2.2.1 4.2.1 5.2.1 6.2.1 6.2.2 6.2.3 7.2.1 7.2.2'
      '7.2.3 7.2.4 7.2.5 7.2.6 7.2.7 7.2.8 8.2.1 8.2.2 8.2.3'
      '8.2.4 8.2.5 8.2.6 8.2.7 8.2.8 8.2.9 8.2.10 8.2.11 0.3.1'
      '6.3.1 6.3.2 6.3.3 7.3.1 8.3.1 8.3.2 8.3.3 8.3.4 8.3.5'
    ]
    @links = []
    for row in [0...12]
        @links[row] = []
        @links[row].theta = 0
        continue if not Table[row]
        for id in Table[row].split(' ')
          link = []
          ranges = (x[1..] for x in root.links when x[0] is id)[0]
          for range in ranges
            knot = {}
            knot.range = range
            knot.color = KnotColors[ranges.indexOf(range)]
            link.push(knot)
          link.iconified = 1
          link.id = id
          @links[row].push(link)
    @links[@selectedRow][@selectedColumn].iconified = 0

  downloadSpineData: ->
    worker = new Worker 'js/downloader.js'
    worker.renderer = this
    worker.onmessage = (response) -> @renderer.onDownloadComplete(response.data)
    worker.postMessage(document.URL + 'data/centerlines.bin')

  onDownloadComplete: (data) ->
    rawVerts = data['centerlines']
    @spines = new Float32Array(rawVerts)
    @vbos.spines = @gl.createBuffer()
    @gl.bindBuffer @gl.ARRAY_BUFFER, @vbos.spines
    @gl.bufferData @gl.ARRAY_BUFFER, @spines, @gl.STATIC_DRAW
    glerr("Error when trying to create spine VBO") unless @gl.getError() == @gl.NO_ERROR
    @tessRow(@links[@selectedRow])
    root.UpdateLabels()
    @render()

  tessRow: (row) ->

    return if row.loaded?
    return if row.loading?

    row.loading = true
    row.loadCount = 0

    onComplete = (event) =>
      link = event.data
      for knot in link
        # Convert Float32Array objects into WebGL VBO's
        # Annotate each VBO with a byte count

        vbo = @gl.createBuffer()
        @gl.bindBuffer(@gl.ARRAY_BUFFER, vbo)
        @gl.bufferData(@gl.ARRAY_BUFFER, knot.vbos.tube, @gl.STATIC_DRAW)
        vbo.count = knot.vbos.tube.length
        knot.vbos.tube = vbo

        vbo = @gl.createBuffer()
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbo)
        @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, knot.vbos.wireframe, @gl.STATIC_DRAW)
        vbo.count = knot.vbos.wireframe.length
        knot.vbos.wireframe = vbo

        vbo = @gl.createBuffer()
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbo)
        @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, knot.vbos.triangles, @gl.STATIC_DRAW)
        vbo.count = knot.vbos.triangles.length
        knot.vbos.triangles = vbo

      if row.loadCount is row.length
        row.loaded = true
        row.loading = false

    useWorkers = false
    for link in row
      if not useWorkers
        @tessLink(link)
        onComplete({data:link})
      else
        worker = new Worker 'js/tess-worker.js'
        msg =
          renderer: this
          link: link
        worker.onmessage = onComplete
        worker.postMessage msg

  tessLink: (link) ->
    for knot in link
      knot.vbos = @tessKnot(knot.range)

  getCurrentLinkInfo: ->
    X = @links[@selectedRow][@selectedColumn].id.split '.'
    return {crossings:X[0], numComponents:"", index:X[1]} if X.length == 2
    {crossings:X[0], numComponents:X[1], index:X[2]}

  moveSelection: (dx,dy) ->
    nextX = @selectedColumn + dx
    nextY = @selectedRow + dy
    return if nextY >= @links.length or nextY < 0
    return if nextX >= @links[nextY].length or nextX < 0
    @changeSelection(nextX, nextY)

  changeSelection: (nextX, nextY) ->
    previousColumn = @selectedColumn
    if nextY isnt @selectedRow
      for link in @links[nextY]
        link.iconified = 1
      @links[nextY][nextX].iconified = 0
      @highlightRow = nextY

    @selectedColumn = nextX
    @selectedRow = nextY
    root.UpdateSelectionRow()
    @tessRow(@links[@selectedRow])
    root.AnimateNumerals()
    row = @links[@selectedRow]

    # Note that "iconified" is an animation percentange in [0,1]
    # If the current selection has animation = 0, then start a new transition.
    iconified = row[previousColumn].iconified
    if iconified is 0
      root.outgoing = new TWEEN.Tween(row[previousColumn])
        .to({iconified: 1}, 0.5 * @transitionMilliseconds)
        .easing(TWEEN.Easing.Quartic.Out)
      root.incoming = new TWEEN.Tween(row[@selectedColumn])
        .to({iconified: 0}, @transitionMilliseconds)
        .easing(TWEEN.Easing.Bounce.Out)
      root.incoming.start()
      root.outgoing.start()
      return

    # If we reached this point, we're interupting an in-progress transition.
    # We instantly snap the currently-incoming element back to the toolbar
    # by forcibly setting its percentage to 1.
    row[previousColumn].iconified = 1
    row[@selectedColumn].iconified = iconified
    root.incoming.replace(row[@selectedColumn]) if root.incoming?

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

    # If we're on the gallery page, update the mouse-over row.
    if root.pageIndex is 0
      h = @height / @links.length
      @highlightRow = Math.floor(root.mouse.position.y / h)
      @highlightRow = null if @highlightRow >= @links.length
      root.UpdateHighlightRow()
    else
      @highlightRow = @selectedRow

    # The HTML/CSS layer can mark the mouse as hot (window.mouse.hot),
    # or the coffeescript logic can make it hot (this.hotMouse).
    cursor = if @hotMouse or root.mouse.hot or root.pageIndex is 0 then 'pointer' else ''
    $('#rightpage').css({'cursor' : cursor})
    $('#leftpage').css({'cursor' : cursor})

    # Update the spinning animation.
    currentTime = new Date().getTime()
    if @previousTime?
      elapsed = currentTime - @previousTime
      dt = @radiansPerSecond * elapsed
      dt = dt * 32 if root.pageIndex is 0
      spinningRow = if @highlightRow? then @links[@highlightRow] else null
      for row in @links
        if row is spinningRow or Math.abs(row.theta % TWOPI) > dt
          row.theta += dt
        else
          row.theta = 0
    @previousTime = currentTime

    # Compute projection and view matrices now.  We'll compute the model matrix later.
    @projection = mat4.perspective(fov = 45, aspect = @width/@height, near = 5, far = 90)
    view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])

    # Compute all viewports before starting the GL calls
    @updateViewports()

    # This is where I'd normally do a glClear, doesn't seem necessary in WebGL
    #@gl.clearColor(0,0,0,0)
    #@gl.clear(@gl.COLOR_BUFFER_BIT)

    # The currently-selected knot is faded out:
    getAlpha = (link) -> 0.25 + 0.75 * link.iconified

    # Draw each knot in its respective viewport, batching roughly
    # according to currently to current shader and current VBO:
    for row in @links

      # Each row has a unique spin theta, so compute the model matrix here.
      model = mat4.create()
      @modelview = mat4.create()
      mat4.identity(model)
      mat4.rotateX(model, 3.14/4)
      mat4.rotateY(model, row.theta)
      mat4.multiply(view, model, @modelview)
      @normalMatrix = mat4.toMat3(@modelview)

      # Render the row in the table on the west page.
      @renderIconLink(link, link.tableBox, alpha = 1) for link in row

      # Now, render the east page.
      if @links.indexOf(row) is @selectedRow
        @renderIconLink(link, link.iconBox, getAlpha link) for link in row
        for pass in [0..1]
          @renderBigLink(link, pass) for link in row

    glerr "Render" unless @gl.getError() == @gl.NO_ERROR

  renderIconLink: (link, viewbox, alpha) -> @renderIconKnot(knot, link, viewbox, alpha) for knot in link
  renderBigLink: (link, pass) -> @renderBigKnot(knot, link, pass) for knot in link

  # Annotates each link with aabb objects: iconBox, centralBox, and tableBox.
  # If a transition animation is underway, centralBox is an interpolated result.
  # The iconBox is inflated if the mouse is nearby, to simulate a Mac Dock effect.
  updateViewports: ->
    bigBox = new aabb 0, 0, @width, @height
    mouse = vec2.create([root.mouse.position.x, @height - root.mouse.position.y])
    @hotMouse = false
    for rowIndex in [0...@links.length]
      row = @links[rowIndex]

      # First populate the tableBox array.
      h = tileHeight = @height / @links.length
      w = tileHeight * @width / @height
      tileWidth = @width / (row.length + 0.5) # <----add some right-hand margin for the arrow icon
      x = -@width + tileWidth / 2
      y = @height - tileHeight / 2 - tileHeight * rowIndex
      for link in row
        link.tableBox = aabb.createFromCenter [x,y], [w,h]
        link.tableBox.inflate(w/5,h/5) # @tileWidth / 10, @tileHeight / 10)
        x = x + tileWidth
      continue if rowIndex isnt @selectedRow

      # Next compute iconBox and centralBox.
      # 'd' is normalized proximity between mouse and icon center.
      w = tileWidth = @width / row.length
      h = tileHeight = tileWidth * @height / @width
      x = tileWidth / 2
      y = @height - tileHeight / 2
      for link in row
        iconBox = aabb.createFromCenter [x,y], [w,h]
        distance = vec2.dist([x,y], mouse)
        radius = h/2
        if distance < radius and link.iconified is 1
          d = 1 - distance / radius
          maxExpansion = radius / 3
          iconBox.inflate(d*d * maxExpansion)
          @hotMouse = true
        link.iconBox = iconBox
        link.centralBox = aabb.lerp bigBox, iconBox, link.iconified
        x = x + w

  # Responds to a mouse click by checking to see if a knot icon was selected.
  click: ->
    if root.pageIndex is 0 and not root.swipeTween?
      return if not @highlightRow?
      @changeSelection(@selectedColumn, @highlightRow)
      root.SwipePane()
      return
    return if not @links?
    row = @links[@selectedRow]
    mouse = vec2.create([root.mouse.position.x, @height - root.mouse.position.y])
    for link in row
      continue if not link or not link.iconBox
      if link.iconBox.contains(mouse[0], mouse[1]) and link.iconified is 1
        @changeSelection(row.indexOf(link), @selectedRow)

  # Shortcut for setting up a vec4 color uniform
  setColor: (loc, c, α) -> @gl.uniform4f(loc, c[0], c[1], c[2], α)

  # Issues a gl.viewport and returns the projection matrix according
  # to the given viewbox.  The viewbox is clipped against the canvas.
  setViewport: (box) ->
    box = box.translated(window.pan.x,0)
    entireViewport = new aabb(0, 0, @width, @height)
    clippedBox = aabb.intersect(box, entireViewport)
    if clippedBox.degenerate()
      return null
    cropMatrix = aabb.cropMatrix(clippedBox, box)
    projection = mat4.create(@projection)
    mat4.multiply(projection, cropMatrix)
    clippedBox.viewport @gl
    return projection

  renderIconKnot: (knot, link, viewbox, alpha) ->
    projection = @setViewport viewbox
    return if not projection

    # Draw the thick black outer line.
    # Large values of lineWidth causes ugly fin gaps.
    # Redraw with screen-space offsets to achieve extra thickness.
    program = @programs.wireframe
    @gl.useProgram(program)
    @gl.enable(@gl.BLEND)
    @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbos.spines)
    @gl.enableVertexAttribArray(POSITION)
    @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 12, 0)
    @gl.uniformMatrix4fv(program.modelview, false, @modelview)
    @gl.uniformMatrix4fv(program.projection, false, projection)
    @gl.uniform1f(program.scale, @tubeGen.scale)
    @setColor(program.color, COLORS.black, alpha)
    [startVertex, vertexCount] = knot.range
    @gl.enable(@gl.DEPTH_TEST)
    @gl.lineWidth(2)
    for x in [-1..1] by 2
      for y in [-1..1] by 2
        @gl.uniform2f(program.offset, x,y)
        @gl.uniform1f(program.depthOffset, 0)
        @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)

    # Draw the center line using the color of the link component.
    @setColor(program.color, knot.color, alpha)
    @gl.uniform2f(program.offset, 0,0)
    @gl.uniform1f(program.depthOffset, -0.5)
    @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)
    @gl.disableVertexAttribArray(POSITION)

  renderBigKnot: (knot, link, pass) ->
    return if link.iconified is 1
    return if not knot.vbos?
    projection = @setViewport link.centralBox
    return if not projection
    vbos = knot.vbos

    # Draw the solid knot
    if pass is 0
        program = @programs.solidmesh
        @gl.enable(@gl.DEPTH_TEST)
        @gl.useProgram(program)
        @setColor(program.color, knot.color, 1)
        @gl.uniformMatrix4fv(program.modelview, false, @modelview)
        @gl.uniformMatrix3fv(program.normalmatrix, false, @normalMatrix)
        @gl.uniformMatrix4fv(program.projection, false, projection)
        @gl.bindBuffer(@gl.ARRAY_BUFFER, vbos.tube)
        @gl.enableVertexAttribArray(POSITION)
        @gl.enableVertexAttribArray(NORMAL)
        @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
        @gl.vertexAttribPointer(NORMAL, 3, @gl.FLOAT, false, stride = 24, offset = 12)
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbos.triangles)
        if @style == Style.SILHOUETTE
          @gl.enable(@gl.POLYGON_OFFSET_FILL)
          @gl.polygonOffset(-1,12)
        @gl.drawElements(@gl.TRIANGLES, vbos.triangles.count, @gl.UNSIGNED_SHORT, 0)
        @gl.disableVertexAttribArray(POSITION)
        @gl.disableVertexAttribArray(NORMAL)
        @gl.disable(@gl.POLYGON_OFFSET_FILL)

    # Draw the wireframe
    if pass is 1
        @gl.enable(@gl.BLEND)
        @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
        program = @programs.wireframe
        @gl.useProgram(program)
        @gl.uniformMatrix4fv(program.modelview, false, @modelview)
        @gl.uniformMatrix4fv(program.projection, false, projection)
        @gl.uniform1f(program.scale, 1)
        @gl.bindBuffer(@gl.ARRAY_BUFFER, vbos.tube)
        @gl.enableVertexAttribArray(POSITION)
        @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbos.wireframe)
        if @style == Style.WIREFRAME
          @gl.lineWidth(1)
          @gl.uniform1f(program.depthOffset, -0.01)
          @setColor(program.color, COLORS.black, 0.75)
          @gl.drawElements(@gl.LINES, vbos.wireframe.count, @gl.UNSIGNED_SHORT, 0)
        else if @style == Style.RINGS
          @gl.lineWidth(1)
          @gl.uniform1f(program.depthOffset, -0.01)
          @setColor(program.color, COLORS.black, 0.75)
          @gl.drawElements(@gl.LINES, vbos.wireframe.count/2, @gl.UNSIGNED_SHORT, vbos.wireframe.count)
        else
          @gl.lineWidth(2)
          @gl.uniform1f(program.depthOffset, 0.01)
          @setColor(program.color, COLORS.black, 1)
          @gl.drawElements(@gl.LINES, vbos.wireframe.count, @gl.UNSIGNED_SHORT, 0)
          if @sketchy
            @gl.lineWidth(1)
            @setColor(program.color, COLORS.darkgray, 1)
            @gl.uniform1f(program.depthOffset, -0.01)
            @gl.drawElements(@gl.LINES, vbos.wireframe.count/2, @gl.UNSIGNED_SHORT, vbos.wireframe.count)
        @gl.disableVertexAttribArray(POSITION)

  # Tessellate the given knot and create VBOs
  tessKnot: (component) ->

    # Perform Bézier interpolation
    byteOffset = component[0] * 3 * 4
    numFloats = component[1] * 3
    segmentData = @spines.subarray(component[0] * 3, component[0] * 3 + component[1] * 3)
    centerline = @tubeGen.getKnotPath(segmentData)

    # Create a positions buffer for a swept octagon
    rawBuffer = @tubeGen.generateTube(centerline)
    tube = rawBuffer

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
    vbos =
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

# PRIVATE UTILITIES #
root.Renderer = Renderer
[sin, cos, pow, abs] = (Math[f] for f in "sin cos pow abs".split(' '))
dot = vec3.dot
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)
TWOPI = 2 * Math.PI
aabb = root.utility.aabb
Style =
  WIREFRAME: 0
  SILHOUETTE: 1
  RINGS: 2
