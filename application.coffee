root = exports ? this

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

  canvas = $("canvas")
  w = parseInt(canvas.css('width'))
  h = parseInt(canvas.css('height'))

  program = programs.vignette
  gl.disable(gl.DEPTH_TEST)
  gl.useProgram(program)
  gl.uniform2f(program.viewport, w, h)
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

# Evaluate a Bezier function for smooth interpolation
GetKnotPath = (data, slices) ->
  rawBuffer = new Float32Array(data.length * slices)
  [i,j] = [0,0]
  while i < data.length - 9
    a = data[i+0...i+3]
    b = data[i+3...i+6]
    c = data[i+6...i+9]
    v1 = vec3.create(a)
    v4 = vec3.create(b)
    vec3.lerp(v1, b, 0.5)
    vec3.lerp(v4, c, 0.5)
    v2 = vec3.create(v1)
    v3 = vec3.create(v4)
    vec3.lerp(v2, b, 1/3)
    vec3.lerp(v3, b, 1/3)
    dt = 1 / (slices+1)
    t = dt
    for slice in [0...slices]
      tt = 1-t
      c = [tt*tt*tt,3*tt*tt*t,3*tt*t*t,t*t*t]
      p = (vec3.create(v) for v in [v1,v2,v3,v4])
      vec3.scale(p[ii],c[ii]) for ii in [0...4]
      #p.reduce(a,b) -> vec3.add
      #p = vec3.add(vec3.add(vec3.add(p[0],p[1]),p[2]),p[3]) # is there a better way?
      rawBuffer.set(p[0], j)
      console.log ">> #{vec3.str(rawBuffer.subarray(i, i+3))}"
      j += 3
      t += dt
    i += 3

GetLinkPaths = (links, slices) ->
  GetKnotPath(link, slices) for link in links

# General VBOs
InitBuffers = ->

  gl = root.gl

  # Create a line loop VBO for a knot centerline
  rawBuffer = GetLinkPaths(window.knot_data, 1)[0]
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.bufferData(gl.ARRAY_BUFFER, rawBuffer, gl.STATIC_DRAW)
  vbos.knotPath = vbo
  vbos.knotPath.count = rawBuffer.length / 3

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
