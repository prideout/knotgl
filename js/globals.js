// Vertex Attribute Semantics
VERTEXID = 0;
POSITION = 0;
NORMAL   = 1;
TEXCOORD = 2;

COLORS = {
    black: [0,0,0],
    darkgray:  [.1,.1,.1],
};

// Global Utilities
function glerr(msg) { $.gritter.add({ title: 'WebGL Error', text: msg }); }
function toast(msg) { $.gritter.add({ title: 'Notice', text: msg }); }

$(document).ready(function(e) {
    window.AppInit();
});
