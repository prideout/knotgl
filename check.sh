#!/bin/bash

# https://github.com/w3c/tidy-html5
tidy -o /dev/null -config tidy.cfg index.html
coffee -co js application.coffee
coffee -co js renderer.coffee
coffee -co js 8.coffee
coffee -co js tube.coffee
coffee -co js shaders.coffee

# https://github.com/srackham/w3c-validator
#w3c-validator.py index.html
