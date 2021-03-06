fs = require 'fs'
path = require 'path'
minimist = require 'minimist'
async = require 'async'
ssh = require 'sshconf-stream'

argv = minimist process.argv.slice 2

# Helper functions

resolvePath = (string) ->
    if string.substr(0,1) == '~'
        string = process.env.HOME + string.substr(1)
    return path.resolve(string)

# Getting configuration together
#
# The first (and currently only) argument is the tug script name,
# which refers to an equivalently named .tug file in the user's
# ~/.tug directory.

tugfile_name = argv._[0]
tugfile_filename = resolvePath "~/.tug/#{ tugfile_name }.tug"
local_tugfile_filename = resolvePath "./.tug"

# Use the local .tug tugfile if available
if !tugfile_name && fs.existsSync local_tugfile_filename
    tugfile_filename = local_tugfile_filename

# Show possible tugfiles if the specified one is not found
else if !fs.existsSync tugfile_filename
    levenshtein = require 'levenshtein'
    tugfiles_available = fs.readdirSync resolvePath "~/.tug/"
    tugfile_distances = tugfiles_available.map (f) ->
        filename: f.split('.')[0]
        distance: levenshtein(tugfile_name, f[0..tugfile_name.length-1])
    tugfile_distances.sort (a, b) -> a.distance - b.distance
    console.log "Tugfile not found. Did you mean `tug #{ tugfile_distances[0].filename }`?"
    process.exit()

# Read through each line in the .tug file to parse
#
# Properties are defined in an ini-inspired format, in which
# each key sits on one line [in brackets], its corresponding value
# is any number of lines of text below it.

tugfile = {}
tugfile_keys = []
tugfile_lines = fs.readFileSync(tugfile_filename).toString().trim().split('\n')

_key = null
_val = ''

for line in tugfile_lines
    if key_matched = line.match /^\[(.+)\]$/
        if _key? && _val?
            tugfile_keys.push _key
            tugfile[_key] = _val.trim()
        _val = ''
        _key = key_matched[1]
    else
        if _key?
            _val += line + '\n'

# Capture the last group as well
if _key? && _val?
    tugfile_keys.push _key
    tugfile[_key] = _val.trim()

# Combine script into one line by joining commands with &&

makeStepScript = (step_name) ->
    tugfile['step ' + step_name].trim().split('\n').join(' && ')

tugfile.steps = tugfile_keys.filter((k) -> k[..3] == 'step').map((s) -> s.slice(5))
tugfile.hosts = tugfile.hosts.trim().split('\n')
if argv.hosts? or argv.h?
    argv_hosts = (argv.hosts || argv.h).split(',')
    tugfile.hosts = tugfile.hosts.filter (h) -> h in argv_hosts

# Run all steps with -a or --all
if argv.all or argv.a
    # Keep steps as they are

# Run a specific step with --step or -s
else if argv_steps = (argv.steps or argv.step or argv.s)
    argv_steps = argv_steps.split(',')
    tugfile.steps = tugfile.steps.filter (s) -> s in argv_steps

# Otherwise run the first step
else
    tugfile.steps = tugfile.steps.slice(0, 1)

# Executing the script
#
# The tug script defines a host parameter, which is assumed to be an
# alias defined in the user's ~/.ssh/config. Once the host details have
# been matched up, the host is connected to and the script is executed.

# Read SSH host data from ~/.ssh/config and determine which host to connect to

fs.createReadStream(resolvePath '~/.ssh/config').pipe(ssh.createParseStream()).on 'data', (_host_data) ->
    host_data = coerceSshconfHost _host_data
    connectToHost host_data if host_data.host in tugfile.hosts

# Turn the data returned by sshconf-stream into a nicer format
# TODO: Find or create a better ssh config parser

coerceSshconfHost = (host_data) ->
    coerced_host_data = {}
    for k, v of host_data.keywords
        coerced_host_data[k.toLowerCase()] = v[0]
    return coerced_host_data

# Connecting to a host with the information retreived from ~/.ssh/config

connectToHost = (host_data) ->
    privateKeyFilename = host_data.identityfile || '~/.ssh/id_rsa'
    privateKey = require('fs').readFileSync resolvePath privateKeyFilename

    ssh_conn = new require('ssh2')()
    ssh_conn.connect
        host: host_data.hostname
        username: host_data.user || process.env.USER
        privateKey: privateKey

    # Once connected, run the steps and output the output

    ssh_conn.on 'ready', ->
        async.mapSeries tugfile.steps, (s, _cb) ->

            step_script = makeStepScript s
            ssh_conn.exec step_script, (err, stream) ->
                stream_output = ''
                stream.on 'data', (data) ->
                    stream_output += data.toString()
                stream.on 'exit', ->
                    console.log "[#{ host_data.host }] #{ s }\n> #{ step_script }\n#{ stream_output }"
                    _cb()

        , -> ssh_conn.end()

