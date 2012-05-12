theta = 0
projection = mat4.create()
modelview = mat4.create()
normalMatrix = mat3.create()

AppRender = ->
  gl.clearColor(0.7,0.5,0.5,1)
  gl.clear(gl.COLOR_BUFFER_BIT)

AppInit = ->
  canvas = $("canvas")
  w = parseInt(canvas.css('width'))
  h = parseInt(canvas.css('height'))
  canvas.css('margin-left', -w/2)
  canvas.css('margin-top', -h/2)
  gl = canvas.get(0).getContext("experimental-webgl")

  if not gl.getExtension("OES_texture_float")
    glerr("Your browser does not support floating-point textures.")

  setInterval(AppRender, 15)

  # Create depth program
  vertexShader = getShader(gl, "VS-Scene")
  fragmentShader = getShader(gl, "FS-Depth")
  depthProgram = gl.createProgram()
  gl.attachShader(depthProgram, vertexShader)
  gl.attachShader(depthProgram, fragmentShader)
  gl.linkProgram(depthProgram)
  if not gl.getProgramParameter(depthProgram, gl.LINK_STATUS)
    glerr('Could not link shaders')

  gl.useProgram(depthProgram)
  depthProgram.positionAttribute = gl.getAttribLocation(depthProgram, "Position")
  depthProgram.normalAttribute = gl.getAttribLocation(depthProgram, "Normal")
  depthProgram.projectionUniform = gl.getUniformLocation(depthProgram, "Projection")
  depthProgram.modelviewUniform = gl.getUniformLocation(depthProgram, "Modelview")
  depthProgram.normalMatrixUniform = gl.getUniformLocation(depthProgram, "NormalMatrix")

  gl.disable(gl.CULL_FACE)
  gl.disable(gl.DEPTH_TEST)

  canvas.width = canvas.clientWidth
  canvas.height = canvas.clientHeight
