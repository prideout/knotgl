root = exports ? this

# Aliases
[sin, cos, pow, abs] = (Math[f] for f in "sin cos pow abs".split(' '))
dot = vec3.dot
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)

DevTips =
  """
  In Chrome, use Ctrl+Shift+J to see console, Alt+Cmd+J on a Mac.
  To experiment with coffescript, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  """

# Vertex Attribute Semantics
VERTEXID = 0
POSITION = 0
NORMAL = 1
TEXCOORD = 2

# Global Constants
TWOPI = 2 * Math.PI

# Various Globals
theta = 0
programs = {}
vbos = {}

# Render Function
Render = ->

  # Wait for a refresh event, look at the current canvas size
  canvas = $("canvas")
  window.requestAnimFrame(Render, canvas.get(0))
  gl = root.gl
  w = parseInt(canvas.css('width'))
  h = parseInt(canvas.css('height'))

  # Adjust the camera and compute various transforms
  projection = mat4.perspective(fov = 45, aspect = 1, near = 5, far = 90)
  view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])
  model = mat4.create()
  modelview = mat4.create()
  mat4.identity(model)
  mat4.rotateY(model, theta)
  mat4.multiply(view, model, modelview)
  normalMatrix = mat4.toMat3(modelview)
  theta += 0.02

  # Draw the hot pink background (why is this so slow?)
  if false
    program = programs.vignette
    gl.disable(gl.DEPTH_TEST)
    gl.useProgram(program)
    gl.uniform2f(program.viewport, w, h)
    gl.bindBuffer(gl.ARRAY_BUFFER, vbos.bigtri)
    gl.enableVertexAttribArray(VERTEXID)
    gl.vertexAttribPointer(VERTEXID, 2, gl.FLOAT, false, stride = 8, 0)
    gl.drawArrays(gl.TRIANGLES, 0, 3)
    gl.disableVertexAttribArray(VERTEXID)

  # Draw the centerline
  if true
    gl.viewport(0,0,w/8,h/8)
    gl.clear(gl.DEPTH_BUFFER_BIT)
    gl.enable(gl.DEPTH_TEST)
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    program = programs.wireframe
    gl.useProgram(program)
    gl.uniformMatrix4fv(program.projection, false, projection)
    gl.uniformMatrix4fv(program.modelview, false, modelview)
    gl.bindBuffer(gl.ARRAY_BUFFER, vbos.centerline)
    gl.enableVertexAttribArray(POSITION)
    gl.vertexAttribPointer(POSITION, 3, gl.FLOAT, false, stride = 12, 0)
    gl.uniform1f(program.scale, 1)
    gl.lineWidth(5)
    gl.uniform4f(program.color, 0,0,0,0.75)
    gl.uniform1f(program.depthOffset, 0)
    gl.drawArrays(gl.LINE_STRIP, 0, vbos.centerline.count)
    gl.lineWidth(2)
    gl.uniform4f(program.color, 1,1,1,0.75)
    gl.uniform1f(program.depthOffset, -0.01)
    gl.drawArrays(gl.LINE_STRIP, 0, vbos.centerline.count)
    gl.disableVertexAttribArray(POSITION)
    gl.viewport(0,0,w,h)

  # Draw the wireframe
  if true
    gl.disable(gl.DEPTH_TEST)
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.lineWidth(1)
    program = programs.wireframe
    gl.useProgram(program)
    gl.uniformMatrix4fv(program.projection, false, projection)
    gl.uniformMatrix4fv(program.modelview, false, modelview)
    gl.uniform4f(program.color, 0.5,0.9,1,0.5)
    gl.uniform1f(program.depthOffset, 0)
    gl.uniform1f(program.scale, 1)
    gl.bindBuffer(gl.ARRAY_BUFFER, vbos.tube)
    gl.enableVertexAttribArray(POSITION)
    gl.vertexAttribPointer(POSITION, 3, gl.FLOAT, false, stride = 12, 0)
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbos.wireframe)
    gl.drawElements(gl.LINES, vbos.wireframe.count, gl.UNSIGNED_SHORT, 0)
    gl.disableVertexAttribArray(POSITION)

  # Draw the Mobius tube
  if false
    program = programs.mesh
    gl.clear(gl.DEPTH_BUFFER_BIT)
    gl.enable(gl.DEPTH_TEST)
    gl.useProgram(program)
    gl.uniformMatrix4fv(program.projection, false, projection)
    gl.uniformMatrix4fv(program.modelview, false, modelview)
    gl.uniformMatrix3fv(program.normalmatrix, false, normalMatrix)
    gl.bindBuffer(gl.ARRAY_BUFFER, vbos.mesh)
    gl.enableVertexAttribArray(POSITION)
    gl.enableVertexAttribArray(NORMAL)
    gl.vertexAttribPointer(POSITION, 3, gl.FLOAT, false, stride = 32, 0)
    gl.vertexAttribPointer(NORMAL, 3, gl.FLOAT, false, stride = 32, offset = 12)
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbos.faces)
    gl.drawElements(gl.TRIANGLES, vbos.faces.count, gl.UNSIGNED_SHORT, 0)
    gl.disableVertexAttribArray(POSITION)
    gl.disableVertexAttribArray(NORMAL)

  if gl.getError() != gl.NO_ERROR
    glerr("Render")

# General VBOs
InitBuffers = ->

  gl = root.gl
  tubeGen = new root.TubeGenerator

  # Create a line strip VBO for a knot centerline
  # The first vertex is repeated for good uv hygiene
  rawBuffer = tubeGen.getLinkPaths(window.knot_data)[0]
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.centerline = vbo
  vbos.centerline.count = rawBuffer.length / 3

  # Create a positions buffer for a swept octagon
  rawBuffer = tubeGen.generateTube(rawBuffer)
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  console.log "Tube positions has #{rawBuffer.length/3} verts."
  vbos.tube = vbo

  # Create the index buffer for the tube wireframe
  polygonCount = vbos.centerline.count - 1
  sides = tubeGen.polygonSides
  lineCount = polygonCount * sides * 2
  rawBuffer = new Uint16Array(lineCount * 2)
  [i, ptr] = [0, 0]
  while i < polygonCount * (sides+1)
    j = 0
    while j < sides
      polygonEdge = rawBuffer.subarray(ptr+0, ptr+2)
      polygonEdge[0] = i+j
      polygonEdge[1] = i+j+1
      sweepEdge = rawBuffer.subarray(ptr+2, ptr+4)
      sweepEdge[0] = i+j
      sweepEdge[1] = i+j+sides+1
      [ptr, j] = [ptr+4, j+1]
    i += sides+1
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.wireframe = vbo
  vbos.wireframe.count = rawBuffer.length
  console.log "Tube wireframe has #{rawBuffer.length} indices for #{sides} sides and #{vbos.centerline.count-1} polygons."

  # Create positions/normals/texcoords for the mobius tube verts
  [Slices, Stacks] = [128, 64]
  rawBuffer = new Float32Array(Slices * Stacks * 8)
  [slice, i] = [-1, 0]
  BmA = CmA = n = N = vec3.create()
  EPSILON = 0.00001
  while ++slice < Slices
    [v, stack] = [slice * TWOPI / (Slices-1), -1]
    while ++stack < Stacks
      u = stack * TWOPI / (Stacks-1)
      A = p = MobiusTube(u, v)
      B = MobiusTube(u + EPSILON, v)
      C = MobiusTube(u, v + EPSILON)
      BmA = vec3.subtract(B,A)
      CmA = vec3.subtract(C,A)
      n = vec3.cross(BmA,CmA)
      n = vec3.normalize(n)
      rawBuffer.set(p, i)
      rawBuffer.set(n, i+3)
      rawBuffer.set([u,v], i+6)
      i += 8
  msg = "#{i} floats generated from #{Slices} slices and #{Stacks} stacks."
  console.log msg
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.mesh = vbo

  # Create the index buffer for the mobius tube faces
  faceCount = (Slices - 1) * Stacks * 2
  rawBuffer = new Uint16Array(faceCount * 3)
  [i, ptr, v] = [0, 0, 0]
  while ++i < Slices
    j = -1
    while ++j < Stacks
      next = (j + 1) % Stacks
      tri = rawBuffer.subarray(ptr+0, ptr+3)
      tri[2] = v+next+Stacks
      tri[1] = v+next
      tri[0] = v+j
      tri = rawBuffer.subarray(ptr+3, ptr+6)
      tri[2] = v+j
      tri[1] = v+j+Stacks
      tri[0] = v+next+Stacks
      ptr += 6
    v += Stacks
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.faces = vbo
  vbos.faces.count = rawBuffer.length

  # Create a fullscreen triangle
  corners = [ -1, 3, -1, -1, 3, -1]
  rawBuffer = new Float32Array(corners)
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.bigtri = vbo

# Parametric Function for the Mobius Tube Surface
MobiusTube = (u, v) ->
  [R, n] = [1.5, 3]
  x = (1.0*R + 0.125*sin(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v)) + 0.5*cos(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)))*cos(u)
  y = (1.0*R + 0.125*sin(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v)) + 0.5*cos(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)))*sin(u)
  z = -0.5*sin(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)) + 0.125*cos(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v))
  [x, y, z]

# Compile and link the given shader strings and metadata
CompileProgram = (vName, fName, attribs, uniforms) ->
  vs = getShader(gl, vName)
  fs = getShader(gl, fName)
  program = gl.createProgram()
  gl.attachShader(program, vs)
  gl.attachShader(program, fs)
  gl.bindAttribLocation(program, value, key) for key, value of attribs
  gl.linkProgram(program)
  if not gl.getProgramParameter(program, gl.LINK_STATUS)
    glerr('Could not link #{vName} with #{fName}')
  program[value] = gl.getUniformLocation(program, key) for key, value of uniforms
  program

# Initialization Function
root.AppInit = ->
  canvas = $("canvas")
  w = parseInt(canvas.css('width'))
  h = parseInt(canvas.css('height'))
  canvas.css('margin-left', -w/2)
  canvas.css('margin-top', -h/2)
  root.gl = gl = canvas.get(0).getContext("experimental-webgl", { antialias: true } )
  if not gl.getExtension("OES_texture_float")
    glerr("Your browser does not support floating-point textures.")
  if not gl.getExtension("OES_standard_derivatives")
    glerr("Your browser does not support GLSL derivatives.")

  # Create Vertex Data
  InitBuffers()

  # Compile Programs
  attribs =
    Position: POSITION
    Normal: NORMAL
  unif =
    Projection: 'projection'
    Modelview: 'modelview'
    NormalMatrix: 'normalmatrix'
  programs.mesh = CompileProgram("VS-Scene", "FS-Scene", attribs, unif)
  attribs =
    Position: POSITION
  unif =
    Projection: 'projection'
    Modelview: 'modelview'
    DepthOffset: 'depthOffset'
    Color: 'color'
    Scale: 'scale'
  programs.wireframe = CompileProgram("VS-Wireframe", "FS-Wireframe", attribs, unif)
  attribs =
    VertexID: VERTEXID
  uniforms =
    Viewport: 'viewport'
  programs.vignette = CompileProgram("VS-Vignette", "FS-Vignette", attribs, uniforms)

  gl.disable(gl.CULL_FACE)
  if gl.getError() != gl.NO_ERROR
    glerr("OpenGL error during init")

  canvas.width = canvas.clientWidth
  canvas.height = canvas.clientHeight
  root.gl = gl
  Render()
