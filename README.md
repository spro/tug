tug
===

tug at the heart of your deployment process

![tugboat](/tugboat.png)

Tug is a super-simple tool to make remote server administration a tiny bit easier. It lets you define common tasks as sets of shell scripts, and provides a simple way to execute those scripts remotely from the comfort of your local shell.

### 1. Define a tug script.

Let's say we want to deploy our website (boat.com) by pulling from a git repository and restarting nginx. We have three hosts to deploy updates to, (each of which has an entry in `~/.ssh/config`). Create a `.tug` file called `~/.tug/boat.tug` like so:

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

### 2. Run it.

```
tug boat
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

That's it! The steps are run in order on each host.

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