var model = new Viewer3D("logo");
// model.ambient(50, 50, 50);
model.shader("transparent", 0, 0, 0);
model.insertModel("/javascripts/polyhedron/triangular_dipyramid.xml");
