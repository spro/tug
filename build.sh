#!/bin/sh

echo "Building tug..."

# Ugly hack to prepend shebang

coffee -o . -c src # Compile coffee source
echo "#!/usr/bin/env node\n" > ./index.js.tmp # Write shebang line to tmp file
cat ./index.js >> ./index.js.tmp # Then cat compiled JS into tmp file
mv ./index.js.tmp ./index.js # Then make tmp file the real file
