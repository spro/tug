#!/bin/sh

echo "Building tug..."

# Compile and prepend shebang to make index.js executable

echo "#!/usr/bin/env node\n" > ./index.js # Write shebang line to index file
coffee -p -c src/tug.coffee >> ./index.js # Then append compiled coffee source

