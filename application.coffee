root = exports ? this

# Vertex Attribute Semantics
VERTEXID = 0
POSITION = 0
NORMAL = 1
TEXCOORD = 2

# Global Constants
Slices = 32 # Cross-Section
Stacks = 96 # Longitunidal
TWOPI = 2 * Math.PI

# Various Globals
theta = 0
programs = {}
vbos = {}

# Shortcuts
[sin, cos, pow, abs] = [Math.sin, Math.cos, Math.pow, Math.abs]
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)

# Main Render Loop
Render = ->

  projection = mat4.perspective(fov = 45, aspect = 1, near = 5, far = 90)
  view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])
  model = mat4.create()
  modelview = mat4.create()
  mat4.identity(model)
  mat4.rotateY(model, theta)
  mat4.multiply(view, model, modelview)
  normalMatrix = mat4.toMat3(modelview)
  theta += 0.02

  gl = root.gl

  program = programs.vignette
  gl.disable(gl.DEPTH_TEST)
  gl.useProgram(program)
  gl.uniform2f(program.viewport, 682, 512)
  gl.bindBuffer(gl.ARRAY_BUFFER, vbos.bigtri)
  gl.enableVertexAttribArray(VERTEXID)
  gl.vertexAttribPointer(VERTEXID, 2, gl.FLOAT, false, stride = 8, 0)
  gl.drawArrays(gl.TRIANGLES, 0, 3)
  gl.disableVertexAttribArray(VERTEXID)

  gl.clear(gl.DEPTH_BUFFER_BIT)
  gl.enable(gl.DEPTH_TEST)

  program = programs.mesh
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

  # Create positions/normals/texcoords for the tube verts
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
      [vertex, i] = [rawBuffer.subarray(i, i+8), i+8]
      vertex[0] = p[0]
      vertex[1] = p[1]
      vertex[2] = p[2]
      vertex[3] = n[0]
      vertex[4] = n[1]
      vertex[5] = n[2]
      vertex[6] = u
      vertex[7] = v
  msg = "#{i} floats generated from #{Slices} slices and #{Stacks} stacks."
  console.log msg # Ctrl+Shift+J to see console, Alt+Cmd+J on a Mac.
  gl = root.gl
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.mesh = vbo

  # Create the index buffer for the tube faces
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

  # Compile Mesh Program
  attribs =
    Position: POSITION
    Normal: NORMAL
  unif =
    Projection: 'projection'
    Modelview: 'modelview'
    NormalMatrix: 'normalmatrix'
  programs.mesh = CompileProgram("VS-Scene", "FS-Scene", attribs, unif)

  # Compile Vignette Program
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
  setInterval(Render, 15)
