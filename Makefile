all:
	echo "#!/usr/bin/env node" > ./index.js   # Write shebang line to index file
	coffee -p -c src/tug.coffee >> ./index.js # Then append compiled coffee source

