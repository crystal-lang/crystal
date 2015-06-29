var canvas = document.getElementById("logo-canvas")
var model = new Viewer3D(canvas);
model.shader("flat", 255, 255, 255);
model.insertModel("/javascripts/polyhedron/icosahedron.xml");
model.contrast(0.90);
