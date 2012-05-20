// Generated by CoffeeScript 1.3.1
(function() {
  var Renderer, Style, TWOPI, abs, cos, dot, f, pow, root, sgn, sin, staticRender, _ref;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  Style = {
    WIREFRAME: 0,
    SILHOUETTE: 1
  };

  Renderer = (function() {

    Renderer.name = 'Renderer';

    function Renderer(gl, width, height) {
      this.gl = gl;
      this.width = width;
      this.height = height;
      this.radiansPerSecond = 0.001;
      this.spinning = true;
      this.style = Style.SILHOUETTE;
      this.theta = 0;
      this.vbos = {};
      this.programs = {};
      this.tubeGen = new root.TubeGenerator;
      this.tubeGen.polygonSides = 16;
      this.tubeGen.bézierSlices = 3;
      this.genMobius();
      this.compileShaders();
      this.genHugeTriangle();
      this.gl.disable(this.gl.CULL_FACE);
      if (this.gl.getError() !== this.gl.NO_ERROR) {
        glerr("OpenGL error during init");
      }
      this.downloadSpines();
    }

    Renderer.prototype.downloadSpines = function() {
      var dataurl, worker;
      worker = new Worker('js/downloader.js');
      worker.gl = this.gl;
      worker.vbos = this.vbos;
      worker.render = this.render;
      worker.renderer = this;
      worker.onmessage = function(response) {
        var rawVerts;
        rawVerts = response.data['centerlines'];
        this.renderer.spines = new Float32Array(rawVerts);
        this.vbos.spines = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vbos.spines);
        this.gl.bufferData(this.gl.ARRAY_BUFFER, this.renderer.spines, this.gl.STATIC_DRAW);
        if (this.gl.getError() !== this.gl.NO_ERROR) {
          lerr("Error when trying to create spine VBO");
        }
        toast("downloaded " + (this.renderer.spines.length / 3) + " verts of spine data");
        this.renderer.genVertexBuffers();
        return this.renderer.render();
      };
      dataurl = document.URL + 'data/centerlines.bin';
      return worker.postMessage(dataurl);
    };

    Renderer.prototype.compileShaders = function() {
      var fs, metadata, name, vs, _ref, _ref1, _results;
      _ref = root.shaders;
      _results = [];
      for (name in _ref) {
        metadata = _ref[name];
        if (name === "source") {
          continue;
        }
        _ref1 = metadata.keys, vs = _ref1[0], fs = _ref1[1];
        _results.push(this.programs[name] = this.compileProgram(vs, fs, metadata.attribs, metadata.uniforms));
      }
      return _results;
    };

    Renderer.prototype.render = function() {
      var aspect, currentTime, elapsed, eye, far, fov, knot, model, modelview, near, normalMatrix, offset, program, projection, setColor, startVertex, stride, target, up, vertexCount, view, _i, _len, _ref, _ref1;
      window.requestAnimFrame(staticRender, $("canvas").get(0));
      projection = mat4.perspective(fov = 45, aspect = 1, near = 5, far = 90);
      view = mat4.lookAt(eye = [0, -5, 5], target = [0, 0, 0], up = [0, 1, 0]);
      model = mat4.create();
      modelview = mat4.create();
      mat4.identity(model);
      mat4.rotateY(model, this.theta);
      mat4.multiply(view, model, modelview);
      normalMatrix = mat4.toMat3(modelview);
      currentTime = new Date().getTime();
      if (this.previousTime != null) {
        elapsed = currentTime - this.previousTime;
        if (this.spinning) {
          this.theta += this.radiansPerSecond * elapsed;
        }
      }
      this.previousTime = currentTime;
      if (false) {
        program = this.programs.vignette;
        this.gl.disable(this.gl.DEPTH_TEST);
        this.gl.useProgram(program);
        this.gl.uniform2f(program.viewport, this.width, this.height);
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vbos.bigtri);
        this.gl.enableVertexAttribArray(VERTEXID);
        this.gl.vertexAttribPointer(VERTEXID, 2, this.gl.FLOAT, false, stride = 8, 0);
        this.gl.drawArrays(this.gl.TRIANGLES, 0, 3);
        this.gl.disableVertexAttribArray(VERTEXID);
      }
      this.gl.clearColor(0, 0, 0, 0);
      this.gl.clear(this.gl.DEPTH_BUFFER_BIT | this.gl.COLOR_BUFFER_BIT);
      this.knots[0].color = [1, 1, 1, 0.75];
      if (this.knots.length > 2) {
        this.knots[1].color = [0.25, 0.5, 1, 0.75];
        this.knots[2].color = [1, 0.5, 0.25, 0.75];
      }
      _ref = this.knots;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        knot = _ref[_i];
        setColor = function(gl, color) {
          return gl.uniform4fv(color, knot.color);
        };
        this.gl.viewport(0, 0, this.width / 12, this.height / 12);
        this.gl.enable(this.gl.DEPTH_TEST);
        this.gl.enable(this.gl.BLEND);
        this.gl.blendFunc(this.gl.SRC_ALPHA, this.gl.ONE_MINUS_SRC_ALPHA);
        program = this.programs.wireframe;
        this.gl.useProgram(program);
        setColor(this.gl, program.color);
        this.gl.uniformMatrix4fv(program.projection, false, projection);
        this.gl.uniformMatrix4fv(program.modelview, false, modelview);
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vbos.spines);
        this.gl.enableVertexAttribArray(POSITION);
        this.gl.vertexAttribPointer(POSITION, 3, this.gl.FLOAT, false, stride = 12, 0);
        this.gl.uniform1f(program.scale, this.tubeGen.scale);
        this.gl.lineWidth(6);
        this.gl.uniform4f(program.color, 0, 0, 0, 0.75);
        this.gl.uniform1f(program.depthOffset, 0);
        _ref1 = knot.centerline, startVertex = _ref1[0], vertexCount = _ref1[1];
        this.gl.drawArrays(this.gl.LINE_LOOP, startVertex, vertexCount);
        this.gl.lineWidth(2);
        setColor(this.gl, program.color);
        this.gl.uniform1f(program.depthOffset, -0.01);
        this.gl.drawArrays(this.gl.LINE_LOOP, startVertex, vertexCount);
        this.gl.disableVertexAttribArray(POSITION);
        this.gl.viewport(0, 0, this.width, this.height);
        program = this.programs.solidmesh;
        this.gl.enable(this.gl.DEPTH_TEST);
        this.gl.useProgram(program);
        setColor(this.gl, program.color);
        this.gl.uniformMatrix4fv(program.projection, false, projection);
        this.gl.uniformMatrix4fv(program.modelview, false, modelview);
        this.gl.uniformMatrix3fv(program.normalmatrix, false, normalMatrix);
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, knot.tube);
        this.gl.enableVertexAttribArray(POSITION);
        this.gl.enableVertexAttribArray(NORMAL);
        this.gl.vertexAttribPointer(POSITION, 3, this.gl.FLOAT, false, stride = 24, 0);
        this.gl.vertexAttribPointer(NORMAL, 3, this.gl.FLOAT, false, stride = 24, offset = 12);
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, knot.triangles);
        if (this.style === Style.SILHOUETTE) {
          this.gl.enable(this.gl.POLYGON_OFFSET_FILL);
          this.gl.polygonOffset(-4, 16);
        }
        this.gl.drawElements(this.gl.TRIANGLES, knot.triangles.count, this.gl.UNSIGNED_SHORT, 0);
        this.gl.disableVertexAttribArray(POSITION);
        this.gl.disableVertexAttribArray(NORMAL);
        this.gl.disable(this.gl.POLYGON_OFFSET_FILL);
        this.gl.enable(this.gl.BLEND);
        this.gl.blendFunc(this.gl.SRC_ALPHA, this.gl.ONE_MINUS_SRC_ALPHA);
        program = this.programs.wireframe;
        this.gl.useProgram(program);
        this.gl.uniformMatrix4fv(program.projection, false, projection);
        this.gl.uniformMatrix4fv(program.modelview, false, modelview);
        this.gl.uniform1f(program.scale, 1);
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, knot.tube);
        this.gl.enableVertexAttribArray(POSITION);
        this.gl.vertexAttribPointer(POSITION, 3, this.gl.FLOAT, false, stride = 24, 0);
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, knot.wireframe);
        if (this.style === Style.WIREFRAME) {
          this.gl.lineWidth(1);
          this.gl.uniform1f(program.depthOffset, -0.01);
          this.gl.uniform4f(program.color, 0, 0, 0, 0.75);
          this.gl.drawElements(this.gl.LINES, knot.wireframe.count, this.gl.UNSIGNED_SHORT, 0);
        } else {
          this.gl.lineWidth(5);
          this.gl.uniform1f(program.depthOffset, 0.01);
          this.gl.uniform4f(program.color, 0, 0, 0, 1);
          this.gl.drawElements(this.gl.LINES, knot.wireframe.count / 2, this.gl.UNSIGNED_SHORT, 0);
        }
        this.gl.disableVertexAttribArray(POSITION);
      }
      if (false) {
        program = this.programs.solidmesh;
        this.gl.enable(this.gl.DEPTH_TEST);
        this.gl.useProgram(program);
        this.gl.uniformMatrix4fv(program.projection, false, projection);
        this.gl.uniformMatrix4fv(program.modelview, false, modelview);
        this.gl.uniformMatrix3fv(program.normalmatrix, false, normalMatrix);
        this.gl.uniform4f(program.color, 1, 1, 1, 1);
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vbos.mesh);
        this.gl.enableVertexAttribArray(POSITION);
        this.gl.enableVertexAttribArray(NORMAL);
        this.gl.vertexAttribPointer(POSITION, 3, this.gl.FLOAT, false, stride = 32, 0);
        this.gl.vertexAttribPointer(NORMAL, 3, this.gl.FLOAT, false, stride = 32, offset = 12);
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.vbos.faces);
        this.gl.drawElements(this.gl.TRIANGLES, this.vbos.faces.count, this.gl.UNSIGNED_SHORT, 0);
        this.gl.disableVertexAttribArray(POSITION);
        this.gl.disableVertexAttribArray(NORMAL);
      }
      if (this.gl.getError() !== this.gl.NO_ERROR) {
        return glerr("Render");
      }
    };

    Renderer.prototype.getLink = function(id) {
      var x, _i, _len, _ref, _results;
      _ref = root.links;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        x = _ref[_i];
        if (x[0] === id) {
          _results.push(x.slice(1));
        }
      }
      return _results;
    };

    Renderer.prototype.genVertexBuffers = function() {
      var byteOffset, centerline, component, components, faceCount, i, j, knot, lineCount, next, numFloats, polygonCount, polygonEdge, ptr, rawBuffer, segmentData, sides, sweepEdge, tri, triangles, tube, v, vbo, wireframe, _i, _len, _ref, _ref1, _ref2, _ref3, _results;
      this.knots = [];
      components = this.getLink("8.3.2")[0];
      _results = [];
      for (_i = 0, _len = components.length; _i < _len; _i++) {
        component = components[_i];
        byteOffset = component[0] * 3 * 4;
        numFloats = component[1] * 3;
        segmentData = this.spines.subarray(component[0] * 3, component[0] * 3 + component[1] * 3);
        centerline = this.tubeGen.getKnotPath(segmentData);
        rawBuffer = this.tubeGen.generateTube(centerline);
        vbo = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, vbo);
        this.gl.bufferData(this.gl.ARRAY_BUFFER, rawBuffer, this.gl.STATIC_DRAW);
        console.log("Tube positions has " + (rawBuffer.length / 3) + " verts.");
        tube = vbo;
        polygonCount = centerline.length / 3 - 1;
        sides = this.tubeGen.polygonSides;
        lineCount = polygonCount * sides * 2;
        rawBuffer = new Uint16Array(lineCount * 2);
        _ref = [0, 0], i = _ref[0], ptr = _ref[1];
        while (i < polygonCount * (sides + 1)) {
          j = 0;
          while (j < sides) {
            sweepEdge = rawBuffer.subarray(ptr + 2, ptr + 4);
            sweepEdge[0] = i + j;
            sweepEdge[1] = i + j + sides + 1;
            _ref1 = [ptr + 2, j + 1], ptr = _ref1[0], j = _ref1[1];
          }
          i += sides + 1;
        }
        i = 0;
        while (i < polygonCount * (sides + 1)) {
          j = 0;
          while (j < sides) {
            polygonEdge = rawBuffer.subarray(ptr + 0, ptr + 2);
            polygonEdge[0] = i + j;
            polygonEdge[1] = i + j + 1;
            _ref2 = [ptr + 2, j + 1], ptr = _ref2[0], j = _ref2[1];
          }
          i += sides + 1;
        }
        vbo = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, vbo);
        this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, rawBuffer, this.gl.STATIC_DRAW);
        wireframe = vbo;
        wireframe.count = rawBuffer.length;
        console.log("Tube wireframe has " + rawBuffer.length + " indices for " + sides + " sides and " + (centerline.length / 3 - 1) + " polygons.");
        faceCount = centerline.length / 3 * sides * 2;
        rawBuffer = new Uint16Array(faceCount * 3);
        _ref3 = [0, 0, 0], i = _ref3[0], ptr = _ref3[1], v = _ref3[2];
        while (++i < centerline.length / 3) {
          j = -1;
          while (++j < sides) {
            next = (j + 1) % sides;
            tri = rawBuffer.subarray(ptr + 0, ptr + 3);
            tri[0] = v + next + sides + 1;
            tri[1] = v + next;
            tri[2] = v + j;
            tri = rawBuffer.subarray(ptr + 3, ptr + 6);
            tri[0] = v + j;
            tri[1] = v + j + sides + 1;
            tri[2] = v + next + sides + 1;
            ptr += 6;
          }
          v += sides + 1;
        }
        vbo = this.gl.createBuffer();
        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, vbo);
        this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, rawBuffer, this.gl.STATIC_DRAW);
        triangles = vbo;
        triangles.count = rawBuffer.length;
        knot = {
          centerline: component,
          tube: tube,
          wireframe: wireframe,
          triangles: triangles
        };
        _results.push(this.knots.push(knot));
      }
      return _results;
    };

    Renderer.prototype.genHugeTriangle = function() {
      var corners, rawBuffer, vbo;
      corners = [-1, 3, -1, -1, 3, -1];
      rawBuffer = new Float32Array(corners);
      vbo = this.gl.createBuffer();
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, vbo);
      this.gl.bufferData(this.gl.ARRAY_BUFFER, rawBuffer, this.gl.STATIC_DRAW);
      return this.vbos.bigtri = vbo;
    };

    Renderer.prototype.genMobius = function() {
      var A, B, BmA, C, CmA, EPSILON, N, Slices, Stacks, faceCount, i, j, msg, n, next, p, ptr, rawBuffer, slice, stack, tri, u, v, vbo, _ref, _ref1, _ref2, _ref3;
      _ref = [128, 64], Slices = _ref[0], Stacks = _ref[1];
      rawBuffer = new Float32Array(Slices * Stacks * 8);
      _ref1 = [-1, 0], slice = _ref1[0], i = _ref1[1];
      BmA = CmA = n = N = vec3.create();
      EPSILON = 0.00001;
      while (++slice < Slices) {
        _ref2 = [slice * TWOPI / (Slices - 1), -1], v = _ref2[0], stack = _ref2[1];
        while (++stack < Stacks) {
          u = stack * TWOPI / (Stacks - 1);
          A = p = this.evalMobius(u, v);
          B = this.evalMobius(u + EPSILON, v);
          C = this.evalMobius(u, v + EPSILON);
          BmA = vec3.subtract(B, A);
          CmA = vec3.subtract(C, A);
          n = vec3.cross(BmA, CmA);
          n = vec3.normalize(n);
          rawBuffer.set(p, i);
          rawBuffer.set(n, i + 3);
          rawBuffer.set([u, v], i + 6);
          i += 8;
        }
      }
      msg = "" + i + " floats generated from " + Slices + " slices and " + Stacks + " stacks.";
      console.log(msg);
      vbo = this.gl.createBuffer();
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, vbo);
      this.gl.bufferData(this.gl.ARRAY_BUFFER, rawBuffer, this.gl.STATIC_DRAW);
      this.vbos.mesh = vbo;
      faceCount = (Slices - 1) * Stacks * 2;
      rawBuffer = new Uint16Array(faceCount * 3);
      _ref3 = [0, 0, 0], i = _ref3[0], ptr = _ref3[1], v = _ref3[2];
      while (++i < Slices) {
        j = -1;
        while (++j < Stacks) {
          next = (j + 1) % Stacks;
          tri = rawBuffer.subarray(ptr + 0, ptr + 3);
          tri[2] = v + next + Stacks;
          tri[1] = v + next;
          tri[0] = v + j;
          tri = rawBuffer.subarray(ptr + 3, ptr + 6);
          tri[2] = v + j;
          tri[1] = v + j + Stacks;
          tri[0] = v + next + Stacks;
          ptr += 6;
        }
        v += Stacks;
      }
      vbo = this.gl.createBuffer();
      this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, vbo);
      this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, rawBuffer, this.gl.STATIC_DRAW);
      this.vbos.faces = vbo;
      return this.vbos.faces.count = rawBuffer.length;
    };

    Renderer.prototype.evalMobius = function(u, v) {
      var R, n, x, y, z, _ref;
      _ref = [1.5, 3], R = _ref[0], n = _ref[1];
      x = (1.0 * R + 0.125 * sin(u / 2) * pow(abs(sin(v)), 2 / n) * sgn(sin(v)) + 0.5 * cos(u / 2) * pow(abs(cos(v)), 2 / n) * sgn(cos(v))) * cos(u);
      y = (1.0 * R + 0.125 * sin(u / 2) * pow(abs(sin(v)), 2 / n) * sgn(sin(v)) + 0.5 * cos(u / 2) * pow(abs(cos(v)), 2 / n) * sgn(cos(v))) * sin(u);
      z = -0.5 * sin(u / 2) * pow(abs(cos(v)), 2 / n) * sgn(cos(v)) + 0.125 * cos(u / 2) * pow(abs(sin(v)), 2 / n) * sgn(sin(v));
      return [x, y, z];
    };

    Renderer.prototype.compileProgram = function(vName, fName, attribs, uniforms) {
      var compileShader, fShader, fSource, key, program, status, vShader, vSource, value;
      compileShader = function(gl, name, handle) {
        var status;
        gl.compileShader(handle);
        status = gl.getShaderParameter(handle, gl.COMPILE_STATUS);
        if (!status) {
          return $.gritter.add({
            title: "GLSL Error: " + name,
            text: gl.getShaderInfoLog(handle)
          });
        }
      };
      vSource = root.shaders.source[vName];
      vShader = this.gl.createShader(this.gl.VERTEX_SHADER);
      this.gl.shaderSource(vShader, vSource);
      compileShader(this.gl, vName, vShader);
      fSource = root.shaders.source[fName];
      fShader = this.gl.createShader(this.gl.FRAGMENT_SHADER);
      this.gl.shaderSource(fShader, fSource);
      compileShader(this.gl, fName, fShader);
      program = this.gl.createProgram();
      this.gl.attachShader(program, vShader);
      this.gl.attachShader(program, fShader);
      for (key in attribs) {
        value = attribs[key];
        this.gl.bindAttribLocation(program, value, key);
      }
      this.gl.linkProgram(program);
      status = this.gl.getProgramParameter(program, this.gl.LINK_STATUS);
      if (!status) {
        glerr("Could not link " + vName + " with " + fName);
      }
      for (key in uniforms) {
        value = uniforms[key];
        program[value] = this.gl.getUniformLocation(program, key);
      }
      return program;
    };

    return Renderer;

  })();

  root.Renderer = Renderer;

  _ref = (function() {
    var _i, _len, _ref, _results;
    _ref = "sin cos pow abs".split(' ');
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      f = _ref[_i];
      _results.push(Math[f]);
    }
    return _results;
  })(), sin = _ref[0], cos = _ref[1], pow = _ref[2], abs = _ref[3];

  dot = vec3.dot;

  sgn = function(x) {
    if (x > 0) {
      return +1;
    } else {
      if (x < 0) {
        return -1;
      } else {
        return 0;
      }
    }
  };

  TWOPI = 2 * Math.PI;

  staticRender = function() {
    return root.renderer.render();
  };

}).call(this);
