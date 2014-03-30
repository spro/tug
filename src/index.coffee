fs = require 'fs'
path = require 'path'
ssh = require 'sshconf-stream'
ssh_conn = new require('ssh2')()

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

script_name = process.argv[2]
conf_filename = resolvePath "~/.tug/#{ script_name }.tug"

conf = {}

# Read through each line in the .tug file to parse
#
# Properties are defined in an ini-inspired format, in which
# each key sits on one line [in brackets], its corresponding value
# is any number of lines of text below it.

conf_lines = fs.readFileSync(conf_filename).toString().trim().split('\n')
_key = null
_val = ''
for line in conf_lines
    if key_matched = line.match /^\[(.+)\]$/
        if _key? && _val?
            conf[_key] = _val.trim()
        _val = ''
        _key = key_matched[1]
    else
        if _key?
            _val += line + '\n'
if _key? && _val?
    conf[_key] = _val.trim()

# Combine script into one line by joining commands with &&

script_oneline = conf.script.trim().split('\n').join(' && ')

# Executing the script
#
# The tug script defines a host parameter, which is assumed to be an
# alias defined in the user's ~/.ssh/config. Once the host details have
# been matched up, the host is connected to and the script is executed.

# Read SSH host data from ~/.ssh/config and determine which host to connect to

fs.createReadStream(resolvePath '~/.ssh/config').pipe(ssh.createParseStream()).on 'data', (_host_data) ->
    host_data = coerce_sshconf_host _host_data
    connect_to_host host_data if host_data.host == conf.host

# Turn the data returned by sshconf-stream into a nicer format
# TODO: Find or create a better ssh config parser

coerce_sshconf_host = (host_data) ->
    coerced_host_data = {}
    for k, v of host_data.keywords
        coerced_host_data[k.toLowerCase()] = v[0]
    return coerced_host_data

# Connecting to a host with the information retreived from ~/.ssh/config

connect_to_host = (host_data) ->
    privateKeyFilename = host_data.identityfile || '~/.ssh/id_rsa'
    privateKey = require('fs').readFileSync resolvePath privateKeyFilename

    ssh_conn.connect
        host: host_data.hostname
        username: host_data.user || process.env.USER
        privateKey: privateKey

    # Once connected, run the deploy script and output the output

    ssh_conn.on 'ready', ->
        ssh_conn.exec script_oneline, (err, stream) ->
            stream.on 'data', (data) ->
                console.log data.toString()
            stream.on 'exit', ->
                ssh_conn.end()

