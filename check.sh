#!/bin/bash

# https://github.com/w3c/tidy-html5
tidy -o /dev/null -config tidy.cfg index.html
coffee -co js application.coffee
coffee -co js 8.coffee

# https://github.com/srackham/w3c-validator
#w3c-validator.py index.html
