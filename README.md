# Run GitHub CI in NetBSD ![Test](https://github.com/vmactions/netbsd-vm/workflows/Test/badge.svg)

Use this action to run your CI in NetBSD.

The github workflow only supports Ubuntu, Windows and MacOS. But what if you need to use NetBSD?

This action is to support NetBSD.


Sample workflow `test.yml`:

```yml

name: Test

on: [push]

jobs:
  test:
    runs-on: macos-12
    name: A job to run test in NetBSD
    env:
      MYTOKEN : ${{ secrets.MYTOKEN }}
      MYTOKEN2: "value2"
    steps:
    - uses: actions/checkout@v2
    - name: Test in NetBSD
      id: test
      uses: vmactions/netbsd-vm@v0
      with:
        envs: 'MYTOKEN MYTOKEN2'
        usesh: true
        prepare: |
          pkg_add curl

        run: |
          pwd
          ls -lah
          whoami
          env





```


The latest major version is: `v0`, which is the most recommended to use. (You can also use the latest full version: `v0.0.6`)  



The `runs-on: macos-12` must be `macos-12`.

The `envs: 'MYTOKEN MYTOKEN2'` is the env names that you want to pass into the vm.

The `run: xxxxx`  is the command you want to run in the vm.

The env variables are all copied into the VM, and the source code and directory are all synchronized into the VM.

The working dir for `run` in the VM is the same as in the Host machine.

All the source code tree in the Host machine are mounted into the VM.

All the `GITHUB_*` as well as `CI=true` env variables are passed into the VM.

So, you will have the same directory and same default env variables when you `run` the CI script.

The default shell in NetBSD is `ksh`, if you want to use `sh` to execute the `run` script, please set `usesh` to `true`.

The code is shared from the host to the VM via `rsync`, you can choose to use to `sshfs` share code instead.


```

...

    steps:
    - uses: actions/checkout@v2
    - name: Test
      id: test
      uses: vmactions/netbsd-vm@v0
      with:
        envs: 'MYTOKEN MYTOKEN2'
        usesh: true
        sync: sshfs
        prepare: |
          pkg_add curl



...


```

You can add NAT port between the host and the VM.

```
...
    steps:
    - uses: actions/checkout@v2
    - name: Test
      id: test
      uses: vmactions/netbsd-vm@v0
      with:
        envs: 'MYTOKEN MYTOKEN2'
        usesh: true
        nat: |
          "8080": "80"
          "8443": "443"
          udp:"8081": "80"
...
```


The default memory of the VM is 1024MB, you can use `mem` option to set the memory size:

```
...
    steps:
    - uses: actions/checkout@v2
    - name: Test
      id: test
      uses: vmactions/netbsd-vm@v0
      with:
        envs: 'MYTOKEN MYTOKEN2'
        usesh: true
        mem: 2048
...
```



It uses [the latest NetBSD 9.2](conf/default.release.conf) by default, you can use `release` option to use another version of NetBSD:

```
...
    steps:
    - uses: actions/checkout@v2
    - name: Test
      id: test
      uses: vmactions/netbsd-vm@v0
      with:
        release: 9.2
...
```

All the supported releases are here: [NetBSD  8.0, 8.1, 8.2, 9.0, 9.1, 9.2](conf)


# Under the hood

GitHub only supports Ubuntu, Windows and MacOS out of the box.

However, the MacOS support virtualization. It has VirtualBox installed.

So, we run the NetBSD VM in VirtualBox on MacOS.


