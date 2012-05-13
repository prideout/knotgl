root = exports ? this

# Vertex Attribute Semantics
POSITION = 0
NORMAL = 1
TEXCOORD = 2

# Global Constants
Slices = 4
Stacks = 4
TWOPI = 2 * Math.PI
EPSILON = 0.0001

# Various Globals
theta = 0

# Shortcuts
[sin, cos, pow, abs] = [Math.sin, Math.cos, Math.pow, Math.abs]
sgn = (x) -> if x > 0 then +1 else (if x < 0 then -1 else 0)

# Main Render Loop
Render = ->

  # Compute transormation matrices and viewing parameters:
  projection = mat4.perspective(fov = 45, aspect = 1, near = 5, far = 90)
  view = mat4.lookAt(eye = [0,-5,5], target = [0,0,0], up = [0,1,0])
  model = mat4.create()
  modelview = mat4.create()
  mat4.identity(model)
  mat4.rotateZ(model, theta)
  mat4.multiply(view, model, modelview)
  normalMatrix = mat4.toMat3(modelview)
  theta += 0.02

  # Update uniforms
  [gl, vbo] = [root.gl, root.vbo]
  program = root.program
  gl.uniformMatrix4fv(program.projectionUniform, false, projection)
  gl.uniformMatrix4fv(program.modelviewUniform, false, modelview)
  gl.uniformMatrix3fv(program.normalMatrixUniform, false, normalMatrix)

  # Issue GL commands
  gl.clearColor(0.5,0.5,0.5,1)
  gl.clear(gl.COLOR_BUFFER_BIT)
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.enableVertexAttribArray(POSITION)
  gl.enableVertexAttribArray(NORMAL)
  gl.vertexAttribPointer(POSITION, 3, gl.FLOAT, false, stride = 32, 0)
  gl.vertexAttribPointer(NORMAL, 3, gl.FLOAT, false, stride = 32, offset = 12)
  gl.drawArrays(gl.TRIANGLES, 0, Slices * Stacks)
  if gl.getError() != gl.NO_ERROR
    glerr("OpenGL error")

# Create VBOs
InitBuffers = ->
  rawBuffer = new Float32Array(Slices * Stacks * 8)
  [slice, i] = [-1, 0]
  BmA = CmA = n = vec3.create()
  while ++slice < Slices
    [v, stack] = [slice * TWOPI / Slices, -1]
    while ++stack < Stacks
      u = stack * TWOPI / Stacks
      A = p = MobiusTube(u, v)
      B = MobiusTube(u + EPSILON, v)
      C = MobiusTube(u, v + EPSILON)
      vec3.subtract(B,A,BmA)
      vec3.subtract(C,A,CmA)
      vec3.cross(BmA,CmA,n)
      vec3.normalize(n,n)
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
  root.vbo = vbo

# Parametric Function for the Mobius Tube Surface
MobiusTube = (u, v) ->
  [R, n] = [1.5, 3]
  x = (1.0*R + 0.125*sin(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v)) + 0.5*cos(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)))*cos(u)
  y = (1.0*R + 0.125*sin(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v)) + 0.5*cos(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)))*sin(u)
  z = -0.5*sin(u/2)*pow(abs(cos(v)), 2/n)*sgn(cos(v)) + 0.125*cos(u/2)*pow(abs(sin(v)), 2/n)*sgn(sin(v))
  [x, y, z]

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

  # Create Program
  vertexShader = getShader(gl, "VS-Scene")
  fragmentShader = getShader(gl, "FS-Scene")
  program = gl.createProgram()
  gl.attachShader(program, vertexShader)
  gl.attachShader(program, fragmentShader)
  gl.bindAttribLocation(program, POSITION, "Position")
  gl.bindAttribLocation(program, NORMAL, "Normal")
  gl.linkProgram(program)
  if not gl.getProgramParameter(program, gl.LINK_STATUS)
    glerr('Could not link shaders')
  gl.useProgram(program)
  program.projectionUniform = gl.getUniformLocation(program, "Projection")
  program.modelviewUniform = gl.getUniformLocation(program, "Modelview")
  program.normalMatrixUniform = gl.getUniformLocation(program, "NormalMatrix")
  root.program = program

  gl.disable(gl.CULL_FACE)
  gl.disable(gl.DEPTH_TEST)

  canvas.width = canvas.clientWidth
  canvas.height = canvas.clientHeight
  root.gl = gl
  setInterval(Render, 15)
