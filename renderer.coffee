root = exports ? this

Style =
  WIREFRAME: 0
  SILHOUETTE: 1

# All WebGL rendering and loading takes place here.  Application logic should live elsewhere.
class Renderer
  constructor: (@gl, @width, @height) ->
    @radiansPerSecond = 0.0001
    @spinning = true
    #@style = Style.SILHOUETTE
    @style = Style.WIREFRAME
    @theta = 0
    @vbos = {}
    @programs = {}
    @tubeGen = new root.TubeGenerator
    @tubeGen.polygonSides = 4
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
    window.requestAnimFrame(staticRender, $("canvas").get(0))

    # Adjust the camera and compute various transforms
    projection = mat4.perspective(fov = 45, aspect = 1, near = 5, far = 90)
    view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])
    model = mat4.create()
    modelview = mat4.create()
    mat4.identity(model)
    mat4.rotateY(model, @theta)
    mat4.multiply(view, model, modelview)
    normalMatrix = mat4.toMat3(modelview)

    currentTime = new Date().getTime()
    if @previousTime?
      elapsed = currentTime - @previousTime
      @theta += @radiansPerSecond * elapsed if @spinning
    @previousTime = currentTime

    @gl.clearColor(0,0,0,0)
    @gl.clear(@gl.DEPTH_BUFFER_BIT | @gl.COLOR_BUFFER_BIT)

    @knots[0].color = [1,1,1,0.75]
    if @knots.length > 2
      @knots[1].color = [0.25,0.5,1,0.75]
      @knots[2].color = [1,0.5,0.25,0.75]

    for knot in @knots

      # Would monkey patching be better?
      setColor = (gl, color) -> gl.uniform4fv(color, knot.color)

      # Draw the centerline
      @gl.viewport(0,0,@width/12,@height/12)
      @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
      program = @programs.wireframe
      @gl.useProgram(program)
      setColor(@gl, program.color)
      @gl.uniformMatrix4fv(program.projection, false, projection)
      @gl.uniformMatrix4fv(program.modelview, false, modelview)
      @gl.bindBuffer(@gl.ARRAY_BUFFER, @vbos.spines)
      @gl.enableVertexAttribArray(POSITION)
      @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 12, 0)
      @gl.uniform1f(program.scale, @tubeGen.scale)
      @gl.uniform4f(program.color,0,0,0,1)
      [startVertex, vertexCount] = knot.centerline
      @gl.disable(@gl.BLEND)
      @gl.enable(@gl.DEPTH_TEST)
      @gl.lineWidth(3)

      # Draw the thick black outer line.
      # Large values of lineWidth causes ugly fin gaps.
      # Redraw with screen-space offsets to achieve extra thickness.
      for x in [-1..1] by 2
        for y in [-1..1] by 2
          @gl.uniform2f(program.offset, x,y)
          @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)

      # Draw a thinner center line down the spine for added depth.
      @gl.enable(@gl.BLEND)
      @gl.lineWidth(2)
      setColor(@gl, program.color)
      @gl.uniform2f(program.offset, 0,0)
      @gl.uniform1f(program.depthOffset, -0.5)
      @gl.drawArrays(@gl.LINE_LOOP, startVertex, vertexCount)
      @gl.disableVertexAttribArray(POSITION)
      @gl.viewport(0,0,@width,@height)

      # Draw the solid knot
      program = @programs.solidmesh
      @gl.enable(@gl.DEPTH_TEST)
      @gl.useProgram(program)
      setColor(@gl, program.color)
      @gl.uniformMatrix4fv(program.projection, false, projection)
      @gl.uniformMatrix4fv(program.modelview, false, modelview)
      @gl.uniformMatrix3fv(program.normalmatrix, false, normalMatrix)
      @gl.bindBuffer(@gl.ARRAY_BUFFER, knot.tube)
      @gl.enableVertexAttribArray(POSITION)
      @gl.enableVertexAttribArray(NORMAL)
      @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
      @gl.vertexAttribPointer(NORMAL, 3, @gl.FLOAT, false, stride = 24, offset = 12)
      @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, knot.triangles)
      if @style == Style.SILHOUETTE
        @gl.enable(@gl.POLYGON_OFFSET_FILL)
        @gl.polygonOffset(-4,16)
      @gl.drawElements(@gl.TRIANGLES, knot.triangles.count, @gl.UNSIGNED_SHORT, 0)
      @gl.disableVertexAttribArray(POSITION)
      @gl.disableVertexAttribArray(NORMAL)
      @gl.disable(@gl.POLYGON_OFFSET_FILL)

      # Draw the wireframe
      @gl.enable(@gl.BLEND)
      @gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
      program = @programs.wireframe
      @gl.useProgram(program)
      @gl.uniformMatrix4fv(program.projection, false, projection)
      @gl.uniformMatrix4fv(program.modelview, false, modelview)
      @gl.uniform1f(program.scale, 1)
      @gl.bindBuffer(@gl.ARRAY_BUFFER, knot.tube)
      @gl.enableVertexAttribArray(POSITION)
      @gl.vertexAttribPointer(POSITION, 3, @gl.FLOAT, false, stride = 24, 0)
      @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, knot.wireframe)
      if @style == Style.WIREFRAME
        @gl.lineWidth(1)
        @gl.uniform1f(program.depthOffset, -0.01)
        @gl.uniform4f(program.color, 0,0,0,0.75)
        @gl.drawElements(@gl.LINES, knot.wireframe.count, @gl.UNSIGNED_SHORT, 0)
      else
        # Draw only longitudinal lines (that's why we divide by 2)
        @gl.lineWidth(5)
        @gl.uniform1f(program.depthOffset, 0.01)
        @gl.uniform4f(program.color, 0,0,0,1)
        @gl.drawElements(@gl.LINES, knot.wireframe.count/2, @gl.UNSIGNED_SHORT, 0)
      @gl.disableVertexAttribArray(POSITION)

    glerr "Render" unless @gl.getError() == @gl.NO_ERROR

  # Returns a list of 'ranges' where each range is an [index, count] pair
  # The required [0] at the end seems like a coffeescript bug but I'm not sure.
  getLink: (id) -> (x[1..] for x in root.links when x[0] is id)[0]

  genVertexBuffers: ->

    @knots = []
    #components = @getLink("8.3.2")
    components = @getLink("8.1")

    for component in components

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

      # Append the knot to the list
      knot =
        centerline: component
        tube: tube
        wireframe: wireframe
        triangles: triangles

      @knots.push knot

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
staticRender = -> root.renderer.render()
