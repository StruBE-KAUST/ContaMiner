#!/bin/sh

seq %MIN_ARRAY% %MAX_ARRAY% | xargs -n 1 -P 12 -I {} contaminer %COMMAND% {}
