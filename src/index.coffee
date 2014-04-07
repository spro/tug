fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
ssh = require 'sshconf-stream'

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

tugfile_name = process.argv[2]
tugfile_filename = resolvePath "~/.tug/#{ tugfile_name }.tug"

tugfile = {}
tugfile_keys = []

# Read through each line in the .tug file to parse
#
# Properties are defined in an ini-inspired format, in which
# each key sits on one line [in brackets], its corresponding value
# is any number of lines of text below it.

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
if _key? && _val?
    tugfile_keys.push _key
    tugfile[_key] = _val.trim()

# Combine script into one line by joining commands with &&

step_script = (step_name) ->
    tugfile['step ' + step_name].trim().split('\n').join(' && ')

tugfile.steps = tugfile_keys.filter((k) -> k[..3] == 'step').map((s) -> s.slice(5))
tugfile.hosts = tugfile.hosts.trim().split('\n')

# Executing the script
#
# The tug script defines a host parameter, which is assumed to be an
# alias defined in the user's ~/.ssh/config. Once the host details have
# been matched up, the host is connected to and the script is executed.

# Read SSH host data from ~/.ssh/config and determine which host to connect to

fs.createReadStream(resolvePath '~/.ssh/config').pipe(ssh.createParseStream()).on 'data', (_host_data) ->
    host_data = coerce_sshconf_host _host_data
    connect_to_host host_data if host_data.host in tugfile.hosts

# Turn the data returned by sshconf-stream into a nicer format
# TODO: Find or create a better ssh config parser

coerce_sshconf_host = (host_data) ->
    coerced_host_data = {}
    for k, v of host_data.keywords
        coerced_host_data[k.toLowerCase()] = v[0]
    return coerced_host_data

execute_steps = (ssh_conn, steps) ->

# Connecting to a host with the information retreived from ~/.ssh/config

connect_to_host = (host_data) ->
    privateKeyFilename = host_data.identityfile || '~/.ssh/id_rsa'
    privateKey = require('fs').readFileSync resolvePath privateKeyFilename

    ssh_conn = new require('ssh2')()
    ssh_conn.connect
        host: host_data.hostname
        username: host_data.user || process.env.USER
        privateKey: privateKey

    # Once connected, run the deploy script and output the output
    steps_script = tugfile.steps.map(step_script).join(' && ')

    ssh_conn.on 'ready', ->
        ssh_conn.exec steps_script, (err, stream) ->
            stream.on 'data', (data) ->
                console.log "[#{ host_data.host }]\n#{ data.toString() }"
            stream.on 'exit', ->
                ssh_conn.end()

