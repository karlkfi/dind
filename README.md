# Docker-in-Docker

This recipe lets you run Docker within Docker.

![Inception's Spinning Top](spintop.jpg)

There is only one requirement: your Docker version should support the
`--privileged` flag.


## Quickstart

Build the image:
```bash
docker build -t dind .
```

Run Docker-in-Docker and get a shell where you can play, and docker daemon logs
to stdout:
```bash
docker run --privileged -t -i dind
```

Run Docker-in-Docker and get a shell where you can play, but docker daemon logs
into `/var/log/docker.log`:
```bash
docker run --privileged -t -i -e LOG=file dind
```

Run Docker-in-Docker and expose the inside Docker to the outside world:
```bash
docker run --privileged -d -p 4444 -e PORT=4444 dind
```

Note: when started with the `PORT` environment variable, the image will just
the Docker daemon and expose it over said port. When started *without* the
`PORT` environment variable, the image will run the Docker daemon in the
background and execute a shell for you to play.

### Daemon configuration

You can use the `DOCKER_DAEMON_ARGS` environment variable to configure the
docker daemon with any extra options:
```bash
docker run --privileged -d -e DOCKER_DAEMON_ARGS="-D" dind
```

## It didn't work!

If you get a weird permission message, check the output of `dmesg`: it could
be caused by AppArmor. In that case, try again, adding an extra flag to
kick AppArmor out of the equation:

```bash
docker run --privileged --lxc-conf="lxc.aa_profile=unconfined" -t -i dind
```

If you get the warning:

````
WARNING: the 'devices' cgroup should be in its own hierarchy.
````

When starting up dind, you can get around this by shutting down docker and running:

````
# /etc/init.d/lxc stop
# umount /sys/fs/cgroup/
# mount -t cgroup devices 1 /sys/fs/cgroup
````

If the unmount fails, you can find out the proper mount-point with:

````
$ cat /proc/mounts | grep cgroup
````

## How It Works

Using Docker-in-Docker has two main caveats: privileged mode, and filesystem.

### Privileged Mode

Docker needs to be able to use kernel features, like cgroups and namespaces.
The `--privileged` flag allows this.

Don't worry, containers created by the inner docker wont have privileged access,
unless you specify `--privileged` when creating them.

### Docker Image Filesystems

By default, Docker stores container images in `/var/lib/docker` and mounts
their pseudo-filesystems from there.

Previous versions of Docker-in-Docker used a volume for `/var/lib/docker`,
but this has several limitations:
- Docker volumes are not garbage collected, causing space leakage.
- Volumes cannot be mounted on Volumes, making more than one layer of Docker
  nesting difficult.

To avoid those limitations, we use one of the following approaches.

#### OverlayFS

OverlayFS is the preferred filesystem to use with Docker for multiple reasons,
but in our case it enabled recursive mounting. This allows Docker to create the
`/var/lib/docker` mount inside a mounted filesystem.

To use OverlayFS, there are two requirements:
1. Make sure your kernel supports OverlayFS (kernel version &amp;= 3.18)
2. [Configure the host Docker daemon](https://docs.docker.com/articles/configuring/) to use OverlayFS (`--storage-driver=overlay`).

#### AUFS

Older kernels do not support OverlayFS. So when OverlayFS is not available,
or the host Docker is not configured to use it, we fallback to AUFS.

Unfortunately AUFS filesystems do not support AUFS mounts.

To work around this, we create a dynamically sized ext3 loopback device and
mount it to `/var/lib/docker`. This way the inner Docker can mount its images
as AUFS filesystems on top of it.

While this approach makes the filesystem transparent to the user,
it also requires space to be pre-allocated such that the loop device has a fixed
maximum size. By default, the max size it configured to be 5GB.

The max loop device size can be changed by specifying a number of GB with
`VAR_LIB_DOCKER_SIZE`.


## Which Version Of Docker Does It Run?

Outside: it will use your installed version.

Inside: the Dockerfile will retrieve the latest `docker` binary from
https://get.docker.io/; so if you want to include *your* own `docker`
build, you will have to edit it. If you want to always use your local
version, you could change the `ADD` line to be e.g.:

    ADD /usr/bin/docker /usr/local/bin/docker


## Can I Run Docker-in-Docker-in-Docker?

Yes. Note, however, that there seems to be a weird FD leakage issue.
To work around it, the `wrapdocker` script carefully closes all the
file descriptors inherited from the parent Docker and `lxc-start`
(except stdio). I'm mentioning this in case you were relying on
those inherited file descriptors, or if you're trying to repeat
the experiment at home.

[kojiromike/inception](https://github.com/kojiromike/inception) is
a wrapper script that uses dind to nest Docker to arbitrary depth.

Also, when you will be exiting a nested Docker, this will happen:

```bash
root@975423921ac5:/# exit
root@6b2ae8bf2f10:/# exit
root@419a67dfdf27:/# exit
root@bc9f450caf22:/# exit
jpetazzo@tarrasque:~/Work/DOTCLOUD/dind$
```

At that point, you should blast Hans Zimmer's [Dream Is Collapsing](
http://www.youtube.com/watch?v=imamcajBEJs) on your loudspeakers while twirling
a spinning top.
