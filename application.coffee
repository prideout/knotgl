root = exports ? this

# Vertex Attribute Semantics
root.POSITION = 0
root.NORMAL = 1

# Various Globals
theta = 0
projection = mat4.create()
modelview = mat4.create()
normalMatrix = mat3.create()

# Main Render Loop
Render = ->
  [gl, vbo] = [root.gl, root.vbo]
  gl.clearColor(0.7,0.5,0.5,1)
  gl.clear(gl.COLOR_BUFFER_BIT)
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  gl.enableVertexAttribArray(root.POSITION)
  gl.vertexAttribPointer(root.POSITION, 3, gl.FLOAT, false, stride = 12, 0)
  gl.drawArrays(gl.TRIANGLES, 0, vbo.vertCount)
  if gl.getError() != gl.NO_ERROR
    glerr("OpenGL error")

# Create VBOs
InitBuffers = ->
  gl = root.gl
  vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  vertices = [
    0.0,  1.0,  0.0
    -0.2, -1.0, 0.0
    1.0, -1.0,  0.0
  ]
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW)
  vbo.vertCount = 3
  root.vbo = vbo

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

  InitBuffers()

  # Create depth program
  vertexShader = getShader(gl, "VS-Scene")
  fragmentShader = getShader(gl, "FS-Depth")
  depthProgram = gl.createProgram()
  gl.attachShader(depthProgram, vertexShader)
  gl.attachShader(depthProgram, fragmentShader)
  gl.bindAttribLocation(depthProgram, root.POSITION, "Position")
  gl.bindAttribLocation(depthProgram, root.NORMAL, "Normal")
  gl.linkProgram(depthProgram)
  if not gl.getProgramParameter(depthProgram, gl.LINK_STATUS)
    glerr('Could not link shaders')

  gl.useProgram(depthProgram)
  depthProgram.projectionUniform = gl.getUniformLocation(depthProgram, "Projection")
  depthProgram.modelviewUniform = gl.getUniformLocation(depthProgram, "Modelview")
  depthProgram.normalMatrixUniform = gl.getUniformLocation(depthProgram, "NormalMatrix")

  gl.disable(gl.CULL_FACE)
  gl.disable(gl.DEPTH_TEST)

  canvas.width = canvas.clientWidth
  canvas.height = canvas.clientHeight
  root.gl = gl
  setInterval(Render, 15)
