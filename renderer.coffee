root = exports ? this

# All WebGL rendering and loading takes place here.  Application logic should live elsewhere.
class Renderer

  constructor: (@gl, @width, @height) ->
    @radiansPerSecond = 0.0003
    @transitionMilliseconds = 750
    @style = Style.SILHOUETTE
    @sketchy = true
    @programs = {}
    @selectedColumn = 0
    @selectedRow = 9
    @hotMouse = false
    @compileShaders()
    @gl.disable @gl.CULL_FACE
    glerr("OpenGL error during init") unless @gl.getError() == @gl.NO_ERROR
    @parseMetadata()
    @worker = new Worker 'js/worker.js'
    @worker.onmessage = (response) => @onWorkerMessage response.data
    msg =
      command: 'download-spines'
      url: document.URL + 'data/centerlines.bin'
    @worker.postMessage(msg)

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
        @links[row].loaded = false
        @links[row].loading = false
        continue if not Table[row]
        for id, col in Table[row].split(' ')
          link = []
          ranges = (x[1..] for x in root.links when x[0] is id)[0]
          for range, c in ranges
            knot = {}
            knot.range = range
            knot.offset = vec3.create([0,0,0])
            knot.color = KnotColors[c]
            link.push(knot)
          link.iconified = 1
          link.ready = false
          link.id = [id, row, col]
          @links[row].push(link)

    trivialKnot = @links[8][1][0]

    # Hack for the 0.1.1 knot
    trivialLink = @links[0][0]
    trivialLink.push(clone trivialKnot)
    trivialLink[0].offset = vec3.create([0.5,-0.25,0])
    trivialLink.hidden = true

    # Hack for the 0.2.1 knot
    trivialLink = @links[8][0]
    trivialLink.push(clone trivialKnot)
    trivialLink.push(clone trivialKnot)
    trivialLink[0].offset = vec3.create([0,0,0])
    trivialLink[1].color = KnotColors[1]
    trivialLink[1].offset = vec3.create([0.5,0,0])

    # Hack for the 0.3.1 knot
    trivialLink = @links[10][8]
    trivialLink.push(clone trivialKnot)
    trivialLink.push(clone trivialKnot)
    trivialLink.push(clone trivialKnot)
    trivialLink[0].offset = vec3.create([0,0,0])
    trivialLink[1].color = KnotColors[1]
    trivialLink[1].offset = vec3.create([0.5,0,0])
    trivialLink[2].color = KnotColors[2]
    trivialLink[2].offset = vec3.create([1.0,0,0])

    @links[@selectedRow][@selectedColumn].iconified = 0

  onWorkerMessage: (msg) ->
    switch msg.command
      when 'debug-message'
        toast msg.text
      when 'spine-data'
        @spines = @createVbo @gl.ARRAY_BUFFER, msg.data
        @spines.scale = msg.scale
        @tessRow @links[@selectedRow]
        root.UpdateLabels()
        @render()
      when 'mesh-link'
        [id, row, col] = msg.id
        link = @links[row][col]
        for mesh, i in msg.meshes
          v = link[i].vbos = {}
          v.tube = @createVbo @gl.ARRAY_BUFFER, mesh.tube
          v.wireframe = @createVbo @gl.ELEMENT_ARRAY_BUFFER, mesh.wireframe
          v.triangles = @createVbo @gl.ELEMENT_ARRAY_BUFFER, mesh.triangles
        row = @links[row]
        if ++row.loadCount is row.length
          row.loaded = true
          row.loading = false
        link.ready = true

  createVbo: (target, data) ->
    vbo = @gl.createBuffer()
    @gl.bindBuffer target, vbo
    @gl.bufferData target, data, @gl.STATIC_DRAW
    vbo.count = data.length
    vbo

  tessRow: (row) ->
    return if row.loaded or row.loading
    row.loading = true
    row.loadCount = 0
    for link in row
      msg =
        command: 'tessellate-link'
        id: link.id
        link: (knot.range for knot in link)
      @worker.postMessage msg

  getCurrentLinkInfo: ->
    X = @links[@selectedRow][@selectedColumn].id[0].split '.'
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
    changingRow = false
    if nextY isnt @selectedRow
      link.iconified = 1 for link in @links[nextY]
      nextX = 0 if not @links[nextY][nextX].ready
      @links[nextY][nextX].iconified = 0
      @highlightRow = nextY
      changingRow = true

    @selectedColumn = nextX
    @selectedRow = nextY
    @tessRow @links[@selectedRow]
    root.AnimateNumerals()
    row = @links[@selectedRow]
    return if changingRow

    # Note that "iconified" is an animation percentange in [0,1]
    # If the current selection has animation = 0, then start a new transition.
    iconified = row[previousColumn].iconified
    if iconified is 0
      duration = @transitionMilliseconds
      @incoming = new TWEEN.Tween(row[@selectedColumn])
        .to(iconified: 0, duration)
        .easing(TWEEN.Easing.Bounce.Out)
        .start()
      duration = 0.5 * @transitionMilliseconds
      @outgoing = new TWEEN.Tween(row[previousColumn])
        .to(iconified: 1, duration)
        .easing(TWEEN.Easing.Quartic.Out)
        .start()
      return

    # If we reached this point, we're interupting an in-progress transition.
    # We instantly snap the currently-incoming element back to the toolbar
    # by forcibly setting its percentage to 1.
    row[previousColumn].iconified = 1
    row[@selectedColumn].iconified = iconified
    @incoming.replace row[@selectedColumn] if @incoming?

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
      @highlightRow = -1 if $('#grasshopper').is ':hover'
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
    for row, rowIndex in @links

      # Each row has a unique spin theta, so compute the model matrix here.
      model = mat4.create()
      @modelview = mat4.create()
      mat4.identity(model)
      mat4.rotateX(model, 3.14/4)
      mat4.rotateY(model, row.theta)
      mat4.multiply(view, model, @modelview)
      @normalMatrix = mat4.toMat3(@modelview)

      # Render the row in the table on the west page.
      (@renderIconLink link, link.tableBox, 1 if not link.hidden?) for link in row

      # Now, render the east page.
      if rowIndex is @selectedRow
        for link in row
          @renderIconLink(link, link.iconBox, getAlpha link) if link.ready
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
    @gl.uniform3f(program.worldOffset, knot.offset[0], knot.offset[1], knot.offset[2])
    @gl.enable(@gl.BLEND)
    @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
    @gl.bindBuffer(@gl.ARRAY_BUFFER, @spines)
    @gl.enableVertexAttribArray(semantics.POSITION)
    @gl.vertexAttribPointer(semantics.POSITION, 3, @gl.FLOAT, false, stride = 12, 0)
    @gl.uniformMatrix4fv(program.modelview, false, @modelview)
    @gl.uniformMatrix4fv(program.projection, false, projection)
    @gl.uniform1f(program.scale, @spines.scale)
    @setColor(program.color, COLORS.black, alpha)
    [startVertex, vertexCount] = knot.range
    @gl.enable(@gl.DEPTH_TEST)
    @gl.lineWidth(2)
    for x in [-1..1] by 2
      for y in [-1..1] by 2
        @gl.uniform2f(program.screenOffset, x,y)
        @gl.uniform1f(program.depthOffset, 0)
        @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)

    # Draw the center line using the color of the link component.
    @setColor(program.color, knot.color, alpha)
    @gl.uniform2f(program.screenOffset, 0,0)
    @gl.uniform1f(program.depthOffset, -0.5)
    @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)
    @gl.disableVertexAttribArray(semantics.POSITION)

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
        @gl.uniform3f(program.worldOffset, knot.offset[0], knot.offset[1], knot.offset[2])
        @gl.uniformMatrix4fv(program.modelview, false, @modelview)
        @gl.uniformMatrix3fv(program.normalmatrix, false, @normalMatrix)
        @gl.uniformMatrix4fv(program.projection, false, projection)
        @gl.bindBuffer(@gl.ARRAY_BUFFER, vbos.tube)
        @gl.enableVertexAttribArray(semantics.POSITION)
        @gl.enableVertexAttribArray(semantics.NORMAL)
        @gl.vertexAttribPointer(semantics.POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
        @gl.vertexAttribPointer(semantics.NORMAL, 3, @gl.FLOAT, false, stride = 24, offset = 12)
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, vbos.triangles)
        if @style == Style.SILHOUETTE
          @gl.enable(@gl.POLYGON_OFFSET_FILL)
          @gl.polygonOffset(-1,12)
        @gl.drawElements(@gl.TRIANGLES, vbos.triangles.count, @gl.UNSIGNED_SHORT, 0)
        @gl.disableVertexAttribArray(semantics.POSITION)
        @gl.disableVertexAttribArray(semantics.NORMAL)
        @gl.disable(@gl.POLYGON_OFFSET_FILL)

    # Draw the wireframe
    if pass is 1
        @gl.enable(@gl.BLEND)
        @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
        program = @programs.wireframe
        @gl.useProgram(program)
        @gl.uniform3f(program.worldOffset, knot.offset[0], knot.offset[1], knot.offset[2])
        @gl.uniformMatrix4fv(program.modelview, false, @modelview)
        @gl.uniformMatrix4fv(program.projection, false, projection)
        @gl.uniform1f(program.scale, 1)
        @gl.bindBuffer(@gl.ARRAY_BUFFER, vbos.tube)
        @gl.enableVertexAttribArray(semantics.POSITION)
        @gl.vertexAttribPointer(semantics.POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
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
        @gl.disableVertexAttribArray(semantics.POSITION)

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
    numUniforms = @gl.getProgramParameter program, @gl.ACTIVE_UNIFORMS
    uniforms = (@gl.getActiveUniform(program, u).name for u in [0...numUniforms])
    program[u] = @gl.getUniformLocation(program, u) for u in uniforms
    program

# PRIVATE UTILITIES #
root.Renderer = Renderer
clone = root.utility.clone
[sin, cos, pow, abs] = (Math[f] for f in "sin cos pow abs".split(' '))
dot = vec3.dot
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)
TWOPI = 2 * Math.PI
aabb = root.utility.aabb
Style =
  WIREFRAME: 0
  SILHOUETTE: 1
  RINGS: 2
