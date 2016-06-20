tug
===

tug at the heart of your deployment process

![tugboat](https://github.com/spro/tug/blob/master/tugboat.png?raw=true)

Tug is a super-simple tool to make remote server administration a tiny bit easier. It lets you define common tasks as sets of shell scripts, and provides a simple way to execute those scripts remotely from the comfort of your local shell.

### 1. Install

Install `tug` globally with  `npm install -g tug`

### 2. Define a tug script

We want to deploy our website, *boat.com*, by pulling updates from a git repository, building the dependencies, and restarting the HTTP daemon. We have three load-balanced web servers and we need to perform the same steps on each.

Make sure each host has an entry in `~/.ssh/config`, and create a `.tug` file called `~/.tug/boat.tug`:

```
[hosts]
www1.boat.com
www2.boat.com
www3.boat.com

[step update]
cd ~/project
git pull

[step build]
cd ~/project
make

[step restart]
nginx -s reload
```

### 3. `tug`

By default the first step in the tugfile is run:

```
tug boat
```

```
[www1.boat.com]
... git updated

[www2.boat.com]
... git updated

[www3.boat.com]
... git updated
```

To run all steps, use the `-a` or `--all` option:

```
tug boat -a
```

```
[www1.boat.com]
... git updated
... project built
... nginx reloaded

[www2.boat.com]
... git updated
... project built
... nginx reloaded

[www3.boat.com]
... git updated
... project built
... nginx reloaded
```

#### Running specific steps

Perhaps you need to reload nginx but don't need or want to update the repository. Steps can be specified on the command line with the `--steps` or `-s` option.

```
tug boat -s restart
```

```
[www1.boat.com]
... nginx reloaded

[www2.boat.com]
... nginx reloaded

[www3.boat.com]
... nginx reloaded
```

Optionally specify multiple steps to run in order, separated with commas:

```
tug boat -s build,restart
```

#### Running on specific hosts

Use the `--hosts` or `-h` option to specify hosts to execute steps on, e.g.:

```
tug boat --hosts www2.boat.com
tug boat -h www3.boat.com --steps update
```

Again optionally specify multiple with commas:

```
tug boat -h www2.boat.com,www3.boat.com -s update,build
```

#### Local .tug files

As an alternative to using a central `~/.tug` directory, you can include a single `.tug` file in your project directory. Tug will look for this file if a name is not specified:

```
cd test
tug -a
```

```
[www.test.com]
... git updated
... project built
... nginx reloaded
```

