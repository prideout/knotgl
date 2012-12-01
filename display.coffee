root = exports ? this
gl = null

root.Display = class Display

  constructor: (context, @width, @height) ->
    gl = context
    @ready = false
    @radiansPerSecond = 0.0003
    @transitionMilliseconds = 750
    @style = Style.SILHOUETTE
    @sketchy = true
    @programs = {}
    @hotMouse = false
    @initializeGL()
    @gallery = new root.Gallery
    @highlightRow = @gallery.j
    @worker = new Worker 'js/worker.min.js'
    @worker.onmessage = (response) => @onWorkerMessage response.data
    msg =
      command: 'download-spines'
      url: document.URL + 'data/centerlines.bin'
    @worker.postMessage(msg)

  render: ->

    # Tessellate the current row of meshes if we haven't already.
    @tessRow() if not @gallery.row().loaded

    # Update the spinning animation.
    currentTime = new Date().getTime()
    if @previousTime?
      elapsed = currentTime - @previousTime
      dt = @radiansPerSecond * elapsed
      dt = dt * 32 if root.pageIndex is 0
      spinningRow = @highlightRow ? null
      spinningRow = @gallery.j if root.pageIndex is 1
      for row, rowIndex in @gallery.links
        if rowIndex is spinningRow or Math.abs(row.theta % TWOPI) > dt
          row.theta += dt
        else
          row.theta = 0
    @previousTime = currentTime

    # Compute projection and view matrices now.  We'll compute the model matrix later.
    @projection = mat4.perspective(fov = 45, aspect = @width/@height, near = 5, far = 90)
    view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])

    # Compute all viewports before starting the GL calls
    @updateViewports()

    # Iterate over each row in the gallery
    for row, rowIndex in @gallery.links

      # Each row has a unique spin theta, so compute the model matrix here.
      model = mat4.create()
      @modelview = mat4.create()
      mat4.identity(model)
      mat4.rotateX(model, 3.14/4)
      mat4.rotateY(model, row.theta)
      mat4.multiply(view, model, @modelview)
      @normalMatrix = mat4.toMat3(@modelview)

      # Update stale alpha
      for link in row
        link.alpha = 0.3 if link.iconified is 0
        link.alpha = 1.0 if link.iconified is 1

      # First, render the row in the table on the west page.
      # Then, render the east page icons and "big" mesh.
      # We roughly batch draw calls according to render state.
      # That's why we don't have an outer loop over the links.
      (@renderIconLink link, link.tableBox, 1 if not link.hidden?) for link in row
      if rowIndex is @gallery.j
        (@renderIconLink(link, link.iconBox, link.alpha) if link.ready) for link in row
        @renderBigLink(link, pass) for link in row for pass in [0..1]

    glerr "Render" unless gl.getError() is gl.NO_ERROR

  renderIconLink: (link, viewbox, alpha) ->
    @renderIconKnot(knot, link, viewbox, alpha) for knot in link

  renderBigLink: (link, pass) ->
    @renderBigKnot(knot, link, pass) for knot in link

  initializeGL: ->
    @compileShaders()
    gl.enable gl.CULL_FACE
    glerr("OpenGL error during init") unless gl.getError() is gl.NO_ERROR

  onWorkerMessage: (msg) ->
    switch msg.command
      when 'debug-message'
        toast msg.text
      when 'spine-data'
        @spines = @createVbo gl.ARRAY_BUFFER, msg.data
        @spines.scale = msg.scale
        @ready = true
      when 'mesh-link'
        [id, row, col] = msg.id
        link = @gallery.link(row,col)
        for mesh, i in msg.meshes
          v = link[i].vbos = {}
          v.tube = @createVbo gl.ARRAY_BUFFER, mesh.tube
          v.wireframe = @createVbo gl.ELEMENT_ARRAY_BUFFER, mesh.wireframe
          v.triangles = @createVbo gl.ELEMENT_ARRAY_BUFFER, mesh.triangles
        row = @gallery.links[row]
        if ++row.loadCount is row.length
          row.loaded = true
          row.loading = false
        link.ready = true

  createVbo: (target, data) ->
    vbo = gl.createBuffer()
    gl.bindBuffer target, vbo
    gl.bufferData target, data, gl.STATIC_DRAW
    vbo.count = data.length
    vbo

  tessRow: ->
    row = @gallery.row()
    return if row.loaded or row.loading or not @ready or root.pageIndex is 0
    row.loading = true
    row.loadCount = 0
    for link in row
      msg =
        command: 'tessellate-link'
        id: link.id
        link: (knot.range for knot in link)
      @worker.postMessage msg

  getCurrentLinkInfo: ->
    X = @gallery.link().id[0].split '.'
    return {crossings:X[0], numComponents:"", index:X[1]} if X.length == 2
    {crossings:X[0], numComponents:X[1], index:X[2]}

  moveSelection: (dx,dy) ->
    nextX = @gallery.i + dx
    nextY = @gallery.j + dy
    return if nextY >= @gallery.links.length or nextY < 0
    return if nextX >= @gallery.links[nextY].length or nextX < 0
    @changeSelection(nextX, nextY)

  changeSelection: (nextX, nextY) ->
    previousColumn = @gallery.i
    changingRow = false
    if nextY isnt @gallery.j
      link.iconified = 1 for link in @gallery.links[nextY]
      nextX = 0 if not @gallery.links[nextY][nextX].ready
      @gallery.links[nextY][nextX].iconified = 0
      @highlightRow = nextY
      changingRow = true

    @gallery.i = nextX
    @gallery.j = nextY
    root.StartNumeralAnimation()
    row = @gallery.row()
    return if changingRow

    # Note that "iconified" is an animation percentange in [0,1]
    # If the current selection has animation = 0, then start a new transition.
    newLink = row[@gallery.i]
    previousLink = row[previousColumn]
    if previousLink.iconified is 0
      duration = @transitionMilliseconds
      @incoming1 = new TWEEN.Tween(newLink).to(alpha: 0.3, duration).start()
      @incoming2 = new TWEEN.Tween(newLink)
        .to(iconified: 0, duration)
        .easing(TWEEN.Easing.Bounce.Out)
        .start()
      duration = 0.5 * @transitionMilliseconds
      new TWEEN.Tween(previousLink).to(alpha: 1.0, duration).start()
      outgoing = new TWEEN.Tween(previousLink)
        .to(iconified: 1, duration)
        .easing(TWEEN.Easing.Quartic.Out)
        .start()
      return

    # If we reached this point, we're interupting an in-progress transition.
    # We instantly snap the currently-incoming element back to the toolbar
    # by forcibly setting its percentage to 1.
    iconified = previousLink.iconified; previousLink.iconified = 1
    newLink.iconified = iconified
    alpha = previousLink.alpha; previousLink.alpha = 1
    newLink.alpha = alpha
    @incoming1.replace newLink if @incoming1?
    @incoming2.replace newLink if @incoming2?

  # Annotates each link with aabb objects: iconBox, centralBox, and tableBox.
  # If a transition animation is underway, centralBox is an interpolated result.
  # The iconBox is inflated if the mouse is nearby, to simulate a Mac Dock effect.
  updateViewports: ->
    bigBox = new aabb 0, 0, @width, @height
    mouse = vec2.create([root.mouse.position.x, @height - root.mouse.position.y])
    @hotMouse = false
    for rowIndex in [0...@gallery.links.length]
      row = @gallery.links[rowIndex]

      # First populate the tableBox array.
      h = tileHeight = @height / @gallery.links.length
      w = tileHeight * @width / @height
      tileWidth = @width / (row.length + 0.5) # <----add some right-hand margin for the arrow icon
      x = -@width + tileWidth / 2
      y = @height - tileHeight / 2 - tileHeight * rowIndex
      for link in row
        link.tableBox = aabb.createFromCenter [x,y], [w,h]
        link.tableBox.inflate(w/5,h/5) # @tileWidth / 10, @tileHeight / 10)
        x = x + tileWidth
      continue if rowIndex isnt @gallery.j

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
    return if not @gallery.links?
    row = @gallery.row()
    mouse = vec2.create([root.mouse.position.x, @height - root.mouse.position.y])
    for link, linkIndex in row
      continue if not link or not link.iconBox
      if link.iconBox.contains(mouse[0], mouse[1]) and link.iconified is 1
        @changeSelection(linkIndex, @gallery.j)

  # Shortcut for setting up a vec4 color uniform
  setColor: (loc, c, α) -> gl.uniform4f(loc, c[0], c[1], c[2], α)

  # Issues a gl.viewport and returns the projection matrix according
  # to the given viewbox.  The viewbox is clipped against the canvas.
  setViewport: (box) ->
    box = box.translated root.pan.x * root.pixelRatio, 0
    entireViewport = new aabb(0, 0, @width, @height)
    clippedBox = aabb.intersect(box, entireViewport)
    if clippedBox.degenerate()
      return null
    cropMatrix = aabb.cropMatrix(clippedBox, box)
    projection = mat4.create(@projection)
    mat4.multiply(projection, cropMatrix)
    clippedBox.viewport gl
    return projection

  renderIconKnot: (knot, link, viewbox, alpha) ->
    projection = @setViewport viewbox
    return if not projection

    # Draw the thick black outer line.
    # Large values of lineWidth causes ugly fin gaps.
    # Redraw with screen-space offsets to achieve extra thickness.
    program = @programs.wireframe
    gl.useProgram(program)
    gl.uniform3f(program.worldOffset, knot.offset[0], knot.offset[1], knot.offset[2])
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.bindBuffer(gl.ARRAY_BUFFER, @spines)
    gl.enableVertexAttribArray(semantics.POSITION)
    gl.vertexAttribPointer(semantics.POSITION, 3, gl.FLOAT, false, stride = 12, 0)
    gl.uniformMatrix4fv(program.modelview, false, @modelview)
    gl.uniformMatrix4fv(program.projection, false, projection)
    gl.uniform1f(program.scale, @spines.scale)
    @setColor(program.color, COLORS.black, alpha)
    [startVertex, vertexCount] = knot.range
    gl.enable(gl.DEPTH_TEST)
    gl.lineWidth(2)
    for x in [-1..1] by 2
      for y in [-1..1] by 2
        gl.uniform2f(program.screenOffset, x,y)
        gl.uniform1f(program.depthOffset, 0)
        gl.drawArrays(gl.LINE_LOOP, startVertex, vertexCount)

    # Draw the center line using the color of the link component.
    @setColor(program.color, knot.color, alpha)
    gl.uniform2f(program.screenOffset, 0,0)
    gl.uniform1f(program.depthOffset, -0.5)
    gl.drawArrays(gl.LINE_LOOP, startVertex, vertexCount)
    gl.disableVertexAttribArray(semantics.POSITION)

  renderBigKnot: (knot, link, pass) ->
    return if link.iconified is 1
    return if not knot.vbos?
    projection = @setViewport link.centralBox
    return if not projection
    vbos = knot.vbos

    # Draw the solid knot
    if pass is 0
        program = @programs.solidmesh
        gl.enable(gl.DEPTH_TEST)
        gl.useProgram(program)
        @setColor(program.color, knot.color, 1)
        gl.uniform3f(program.worldOffset, knot.offset[0], knot.offset[1], knot.offset[2])
        gl.uniformMatrix4fv(program.modelview, false, @modelview)
        gl.uniformMatrix3fv(program.normalmatrix, false, @normalMatrix)
        gl.uniformMatrix4fv(program.projection, false, projection)
        gl.bindBuffer(gl.ARRAY_BUFFER, vbos.tube)
        gl.enableVertexAttribArray(semantics.POSITION)
        gl.enableVertexAttribArray(semantics.NORMAL)
        gl.vertexAttribPointer(semantics.POSITION, 3, gl.FLOAT, false, stride = 24, 0)
        gl.vertexAttribPointer(semantics.NORMAL, 3, gl.FLOAT, false, stride = 24, offset = 12)
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbos.triangles)
        if @style == Style.SILHOUETTE
          gl.enable(gl.POLYGON_OFFSET_FILL)
          gl.polygonOffset(-1,12)
        gl.drawElements(gl.TRIANGLES, vbos.triangles.count, gl.UNSIGNED_SHORT, 0)
        gl.disableVertexAttribArray(semantics.POSITION)
        gl.disableVertexAttribArray(semantics.NORMAL)
        gl.disable(gl.POLYGON_OFFSET_FILL)

    # Draw the wireframe
    if pass is 1
        gl.enable(gl.BLEND)
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        program = @programs.wireframe
        gl.useProgram(program)
        gl.uniform3f(program.worldOffset, knot.offset[0], knot.offset[1], knot.offset[2])
        gl.uniformMatrix4fv(program.modelview, false, @modelview)
        gl.uniformMatrix4fv(program.projection, false, projection)
        gl.uniform1f(program.scale, 1)
        gl.bindBuffer(gl.ARRAY_BUFFER, vbos.tube)
        gl.enableVertexAttribArray(semantics.POSITION)
        gl.vertexAttribPointer(semantics.POSITION, 3, gl.FLOAT, false, stride = 24, 0)
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbos.wireframe)
        if @style == Style.WIREFRAME
          gl.lineWidth(1)
          gl.uniform1f(program.depthOffset, -0.01)
          @setColor(program.color, COLORS.black, 0.75)
          gl.drawElements(gl.LINES, vbos.wireframe.count, gl.UNSIGNED_SHORT, 0)
        else if @style == Style.RINGS
          gl.lineWidth(1)
          gl.uniform1f(program.depthOffset, -0.01)
          @setColor(program.color, COLORS.black, 0.75)
          gl.drawElements(gl.LINES, vbos.wireframe.count/2, gl.UNSIGNED_SHORT, vbos.wireframe.count)
        else
          gl.lineWidth(2)
          gl.uniform1f(program.depthOffset, 0.01)
          @setColor(program.color, COLORS.black, 1)
          gl.drawElements(gl.LINES, vbos.wireframe.count, gl.UNSIGNED_SHORT, 0)
          if @sketchy
            gl.lineWidth(1)
            @setColor(program.color, COLORS.darkgray, 1)
            gl.uniform1f(program.depthOffset, -0.01)
            gl.drawElements(gl.LINES, vbos.wireframe.count/2, gl.UNSIGNED_SHORT, vbos.wireframe.count)
        gl.disableVertexAttribArray(semantics.POSITION)

  compileShaders: ->
    for name, metadata of root.shaders
      continue if name == "source"
      [vs, fs] = metadata.keys
      @programs[name] = @compileProgram vs, fs, metadata.attribs, metadata.uniforms

  compileShader: (name, type) ->
    source = root.shaders.source[name]
    handle = gl.createShader type
    gl.shaderSource handle, source
    gl.compileShader handle
    status = gl.getShaderParameter handle, gl.COMPILE_STATUS
    $.gritter.add {title: "GLSL Error: #{name}", text: gl.getShaderInfoLog(handle)} unless status
    handle

  compileProgram: (vName, fName, attribs, uniforms) ->
    vShader = @compileShader vName, gl.VERTEX_SHADER
    fShader = @compileShader fName, gl.FRAGMENT_SHADER
    program = gl.createProgram()
    gl.attachShader program, vShader
    gl.attachShader program, fShader
    gl.bindAttribLocation(program, value, key) for key, value of attribs
    gl.linkProgram program
    status = gl.getProgramParameter(program, gl.LINK_STATUS)
    glerr("Could not link #{vName} with #{fName}") unless status
    numUniforms = gl.getProgramParameter program, gl.ACTIVE_UNIFORMS
    uniforms = (gl.getActiveUniform(program, u).name for u in [0...numUniforms])
    program[u] = gl.getUniformLocation(program, u) for u in uniforms
    program

# PRIVATE UTILITIES #
clone = utility.clone
[sin, cos, pow, abs] = (Math[f] for f in "sin cos pow abs".split(' '))
dot = vec3.dot
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)
TWOPI = 2 * Math.PI
aabb = utility.aabb
Style =
  WIREFRAME: 0
  SILHOUETTE: 1
  RINGS: 2
