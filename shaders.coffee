root = exports ? this

v = root.semantics =
  VERTEXID: 0
  POSITION: 0
  NORMAL: 1
  TEXCOORD: 2

root.shaders =
  mesh:
    keys: ["VS-Scene", "FS-Scene"]
    attribs:
      Position: v.POSITION
      Normal: v.NORMAL
    uniforms:
      Projection: 'projection'
      Modelview: 'modelview'
      NormalMatrix: 'normalmatrix'

  wireframe:
    keys: ["VS-Wireframe", "FS-Wireframe"]
    attribs:
      Position: v.POSITION
    uniforms:
      Projection: 'projection'
      Modelview: 'modelview'
      DepthOffset: 'depthOffset'
      Color: 'color'
      Scale: 'scale'

  vignette:
    keys: ["VS-Vignette", "FS-Vignette"]
    attribs:
      VertexID: v.VERTEXID
    uniforms:
      Viewport: 'viewport'
