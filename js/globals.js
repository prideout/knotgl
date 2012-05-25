// Vertex Attribute Semantics
VERTEXID = 0;
POSITION = 0;
NORMAL   = 1;
TEXCOORD = 2;

// Global Utilities
function glerr(msg) { $.gritter.add({ title: 'WebGL Error', text: msg }); }
function toast(msg) { $.gritter.add({ title: 'Notice', text: msg }); }

// Key Handler
$(document).keydown(function(e){
    if (e.keyCode == 37) window.OnKeyDown('left');
    if (e.keyCode == 39) window.OnKeyDown('right');
});
