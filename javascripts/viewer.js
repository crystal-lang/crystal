function Viewer3D(name) {

  var self = this;
  self.name = name;
  self.width = document.getElementById(name).width;
  self.height = document.getElementById(name).height;

  var _vertices, _faces, _canvas, _ambient, _shader, _req, _renderInterval, _dragging, _container;
  var _min = 0.01;
  var _yaw = _min;
  var _pitch = _min;
  var _distance = 4;
  var _scale = self.width * (4 / 3);
  var _r = [[1, 0, 0],
            [0, 1, 0],
            [0, 0, 1]];
  var _loaded = false;
  var _start;

  self.insertModel = function(url) {
    window.clearInterval(_renderInterval);
    _renderInterval = undefined;
    lastOnload = window.onload;
    if(_loaded) {
      onloadDocument(url);
    } else {
      window.onload = function() {
        _loaded = true;
        onloadDocument(url);
        if (lastOnload) {
          lastOnload();
        }
      }
    }
  }

  self.ambient = function(r, g, b) {
    _ambient = {r:r, g:g, b:b};
  }

  self.shader = function(id, r, g, b) {
    switch(id) {
      case "transparent":
        _shader = new TransparentShader(r, g, b);
        break;
      case "flat":
        _shader = new FlatShader(r, g, b);
        break;
    }
  }

  self.toScreenX = function(x, z) {
    return self.width / 2 + _scale * x / (_distance - z);
  }

  self.toScreenY = function(y, z) {
    return self.height / 2 + _scale * y / (_distance - z);
  }

  //Geometry

  function rotate(point3D) {
    var x = point3D.x * _r[0][0] + point3D.y * _r[0][1] + point3D.z * _r[0][2];
    var y = point3D.x * _r[1][0] + point3D.y * _r[1][1] + point3D.z * _r[1][2];
    var z = point3D.x * _r[2][0] + point3D.y * _r[2][1] + point3D.z * _r[2][2];
    return {x:x, y:y, z:z};
  }

  function matrixMultiply(a, b) {
    var matrix = [[0,0,0], [0,0,0], [0,0,0]];
    for(var i = 0; i < 3; i++) {
      for(var j = 0; j < 3; j++) {
        for(var k = 0; k < 3; k++) {
          matrix[i][j] += a[i][k] * b[k][j];
        }
      }
    }
    return matrix;
  }

  function transformVertices() {
    for(var i = 0; i < _vertices.length; i++) {
      var vertex = _vertices[i];
      var xp = vertex.x * _r[0][0] + vertex.y * _r[0][1] + vertex.z * _r[0][2];
      var yp = vertex.x * _r[1][0] + vertex.y * _r[1][1] + vertex.z * _r[1][2];
      var zp = vertex.x * _r[2][0] + vertex.y * _r[2][1] + vertex.z * _r[2][2];
      vertex.screenX = self.width / 2 + _scale * xp / (_distance - zp);
      vertex.screenY = self.height / 2 + _scale * yp / (_distance - zp);
    }
  }

  function render() {
    _canvas.clearRect(0 , 0, self.width, self.height);
    transformVertices();
    rotateVectors();
    _shader.render();
  }

  function rotateVectors() {
    for(var i = 0; i < _faces.length; i++) {
      var face = _faces[i];
      face.transform = new Object();
      face.transform.normal = rotate(face.normal);
      face.transform.centroid = rotate(face.centroid);
    }
  }

  function sortByNormal() {
    var order = new Array();
    for(var i = 0; i < _faces.length; i++) {
      order[i] = i;
    }
    order.sort(function (a, b) {
      var deltaNormal = _faces[b].transform.normal.z - _faces[a].transform.normal.z;
      if (deltaNormal > 0) {
        return -1;
      } else if (deltaNormal < 0) {
        return 1;
      } else {
        return 0;
      }
    });
    return order;
  }

  function computeCentroid(face) {
    var centroid = {x:0, y:0, z:0};
    for(var i = 0; i < face.vertices.length; i++) {
      var id = face.vertices[i];
      var vertex = _vertices[id];
      centroid.x += vertex.x;
      centroid.y += vertex.y;
      centroid.z += vertex.z;
    }
    centroid.x /= face.vertices.length;
    centroid.y /= face.vertices.length;
    centroid.z /= face.vertices.length;
    return centroid;
  }

  function computeCentroids () {
    for(var i = 0; i < _faces.length; i++) {
      var face = _faces[i];
      face.centroid = computeCentroid(face);
    }
  }

  function computeNormal(face) {
    var vertex0 = _vertices[face.vertices[0]];
    var vertex1 = _vertices[face.vertices[1]];
    var vertex2 = _vertices[face.vertices[2]];
    var a = {x:vertex1.x - vertex0.x, y:vertex1.y - vertex0.y, z:vertex1.z - vertex0.z};
    var b = {x:vertex2.x - vertex0.x, y:vertex2.y - vertex0.y, z:vertex2.z - vertex0.z};
    var normal = new Object();
    normal.x = a.y * b.z - a.z * b.y;
    normal.y = a.z * b.x - a.x * b.z;
    normal.z = a.x * b.y - a.y * b.x;
    var magnitude = Math.sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z);
    normal.x /= magnitude;
    normal.y /= magnitude;
    normal.z /= magnitude;
    var flip = normal.x * face.centroid.x + normal.y * face.centroid.y + normal.z * face.centroid.z < 0;
    if(flip) {
      normal.x = -normal.x;
      normal.y = -normal.y;
      normal.z = -normal.z;
    }
    return normal;
  }

  function computeNormals () {
    for(var i = 0; i < _faces.length; i++) {
      var face = _faces[i];
      face.normal = computeNormal(face);
    }
  }

  function animate() {
    _r = matrixMultiply([[Math.cos(_yaw), 0, -Math.sin(_yaw)],[0, 1, 0],[Math.sin(_yaw), 0, Math.cos(_yaw)]], _r);
    _r = matrixMultiply([[1, 0, 0], [0, Math.cos(_pitch), -Math.sin(_pitch)], [0, Math.sin(_pitch), Math.cos(_pitch)]], _r);
    render();
    if(_dragging) {
      _yaw = 0;
      _pitch = 0;
    } else {
      _yaw = decelerate(_yaw);
      _pitch = decelerate(_pitch);
    }
    if(_renderInterval == undefined) {
     _renderInterval = window.setInterval(animate, 20);
    }
  }

  function decelerate(value) {
    if (!value) {
      return 0.0001 * (Math.round(Math.random())? 1 : -1);
    } else if(Math.abs(value) < _min) {
      value *= 1.01;
    } else {
      value *= 0.99;
       if(value < 0) {
        value = Math.min(value, -_min);
      } else {
        value = Math.max(value, _min);
      }
    }
    return value;
  }

  //Shaders

  function TransparentShader(r, g, b) {
    var _stroke = "rgb(" + r + "," + g + "," + b + ")";
    this.render = function () {
      var edges = new Array();
      for(var i = 0; i < _faces.length; i++) {
        var face = _faces[i];
        var isFrontface = face.transform.centroid.x * face.transform.normal.x + face.transform.centroid.y * face.transform.normal.y + (face.transform.centroid.z -_distance) * face.transform.normal.z < 0;
        for(var j = 0; j < face.vertices.length; j++) {
          var a = face.vertices[j];
          var b = j + 1 < face.vertices.length? face.vertices[j + 1] : face.vertices[0];
          var key = Math.min(a, b) + " " + Math.max(a, b);
          edges[key] = edges[key] || isFrontface;
        }
      }
      _canvas.fillStyle = "transparent";
      _canvas.strokeStyle = _stroke;
      for (var key in edges) {
        var ids = key.split(" ");
        var isFrontface = edges[key];
        _canvas.lineWidth = isFrontface? 0.5 : 0.1;
        _canvas.beginPath();
        _canvas.moveTo(_vertices[ids[0]].screenX, _vertices[ids[0]].screenY);
        _canvas.lineTo(_vertices[ids[1]].screenX, _vertices[ids[1]].screenY);
        _canvas.closePath();
        _canvas.stroke();
      }
    }
  }

  function FlatShader(r, g, b) {
    var _lights = new Array();
    _lights.push(new Light(10, -10, 10, r, g, b));
    _lights.push(new Light(0, 0, 10, 50, 50, 50));

    this.fill = function (face) {
      var r = _ambient.r;
      var g = _ambient.g;
      var b = _ambient.b;
      for(var i = 0; i < _lights.length; i++) {
        var cos = face.transform.normal.x * _lights[i].x + face.transform.normal.y * _lights[i].y + face.transform.normal.z * _lights[i].z;
        if(cos > 0) {
          r = Math.max(0, Math.min(255, Math.round(r + cos * _lights[i].r)));
          g = Math.max(0, Math.min(255, Math.round(g + cos * _lights[i].g)));
          b = Math.max(0, Math.min(255, Math.round(b + cos * _lights[i].b)));
        }
      }
      var value = "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).substring(1);
      return value;
    };

    this.render = function () {
      var order = sortByNormal();
      for(var i = 0; i < order.length; i++) {
        var face = _faces[order[i]];
        var isBackface = face.transform.normal.z <= 0;
        if(!isBackface) {
          var color = this.fill(face);
          _canvas.strokeStyle = color;
          _canvas.fillStyle = color;
          _canvas.lineWidth = 0.5;
          _canvas.beginPath();
          for(var j = 0; j < face.vertices.length; j++) {
            var id = face.vertices[j];
            var vertex = _vertices[id];
            if(!j) {
              _canvas.moveTo(vertex.screenX, vertex.screenY);
            }
            _canvas.lineTo(vertex.screenX, vertex.screenY);
          }
          _canvas.closePath();
          _canvas.fill();
          _canvas.stroke();
        }
      }
    }
  }

  function Light(x, y, z, r, g, b) {
    var length = Math.sqrt(Math.pow(x, 2) + Math.pow(y, 2) + Math.pow(z, 2));
    this.x = x / length;
    this.y = y / length;
    this.z = z / length;
    this.r = r;
    this.g = g;
    this.b = b;
  }

  //Model

  function fetchXML(url) {
    _req = getXMLRequestObject();
    _req.onreadystatechange = function() {
      loadGeometry();
    }
    _req.open("GET", url, true);
    _req.send("");
  }

  function loadGeometry() {
    if (_req.readyState == 4) {
      if (_req.status == 200) {
        var xml = _req.responseXML;
        var vertices = xml.getElementsByTagName("p");
        _vertices = new Array();
        for (var i = 0; i < vertices.length; i++) {
          var vertex = new Object();
          vertex.x = Number(vertices[i].getAttribute("x"));
          vertex.y = Number(vertices[i].getAttribute("y"));
          vertex.z = Number(vertices[i].getAttribute("z"));
          _vertices[i] = vertex;
        }
        var faces = xml.getElementsByTagName('f');
        _faces = new Array();
        for (var i = 0; i < faces.length; i++) {
          _faces[i] = {vertices:new Array()};
          for(j = 0; j < faces[i].childNodes.length; j++) {
            _faces[i].vertices[j] = faces[i].childNodes[j].firstChild.nodeValue;
          }
        }
        computeCentroids();
        computeNormals();
        animate();
      } else {
        alert("xml request error: " + _req.statusText);
      }
    }
  }

  function getXMLRequestObject() {
    if (window.XMLHttpRequest) {
      return new XMLHttpRequest();
    } else if (window.ActiveXObject) {
      return new ActiveXObject("Microsoft.XMLHTTP");
    }
    alert("Can't find XML Http Request object!");
  }

   function onloadDocument(url) {
    _container = document.getElementById(self.name);
    _container.addEventListener("mousedown", mouseDownHandler, false);
    _canvas = _container.getContext("2d");
    fetchXML(url);
  }

  function mouseDownHandler(event) {
    var bounds = _container.getBoundingClientRect();
    var x = event.clientX - bounds.left;
    var y = event.clientY - bounds.top;
    _dragging = true;
    _last = {point:{x:x, y:y}};
    window.addEventListener("mousemove", mouseMoveHandler, false);
    window.addEventListener("mouseup", mouseUpHandler, false);
  }

  function mouseUpHandler(event) {
    _dragging = false;
    window.removeEventListener("mousemove", mouseMoveHandler, false);
    window.removeEventListener("mouseup", mouseUpHandler, false);
  }

  function mouseMoveHandler(event) {
    var bounds = _container.getBoundingClientRect();
    var x = event.clientX - bounds.left;
    var y = event.clientY - bounds.top;
    var depth = _scale  / _distance / 2;
    _yaw = Math.atan2(_last.point.x - self.width / 2 , depth) - Math.atan2(x - self.width / 2 , depth);
    _pitch = Math.atan2(_last.point.y - self.height / 2, depth) - Math.atan2(y - self.height / 2, depth);
    _last = {point:{x:x, y:y}};
  }

  self.shader("flat", 100, 100, 100);
  self.ambient(0, 0, 0);
}
