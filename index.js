const core = require('@actions/core');
const exec = require('@actions/exec');
const tc = require('@actions/tool-cache');
const io = require('@actions/io');
const fs = require("fs");
const path = require("path");



var osname = "netbsd";
var loginTag = "NetBSD/amd64 (localhost) (constty)";
    
    
    
async function execSSH(cmd, desp = "") {
  core.info(desp);
  core.info("exec ssh: " + cmd);
  await exec.exec("ssh -t " + osname, [], { input: cmd });
}


async function shell(cmd) {
  core.info("exec shell: " + cmd);
  await exec.exec("bash", [], { input: cmd });
  
}


async function setup(nat, mem) {
  try {
    await shell("bash run.sh importVM");

    await shell("cd " + workingDir + " && pwd && ls -lah" );
    await shell("bash -c 'pwd && ls -lah ~/.ssh/ && cat ~/.ssh/config'" );

    let workingDir = __dirname;
    if (nat) {
      let nats = nat.split("\n").filter(x => x !== "");
      for (let element of nats) {
        core.info("Add nat: " + element);
        let segs = element.split(":");
        if (segs.length === 3) {
          //udp:"8081": "80"
          let proto = segs[0].trim().trim('"');
          let hostPort = segs[1].trim().trim('"');
          let vmPort = segs[2].trim().trim('"');

          await shell("cd " + workingDir + " && " + "bash vbox.sh addNAT " + osname + " " + proto + " " + hostPort + " " + vmPort);

        } else if (segs.length === 2) {
          let proto = "tcp"
          let hostPort = segs[0].trim().trim('"');
          let vmPort = segs[1].trim().trim('"');
          await shell("cd " + workingDir + " && " + "bash vbox.sh addNAT " + osname + " " + proto + " " + hostPort + " " + vmPort);
        }
      };
    }

    if (mem) {
      await shell("cd " + workingDir + " && " + "bash vbox.sh setMemory " + osname + " " + mem);
    }

    await shell("cd " + workingDir + " && " + "bash vbox.sh setCPU " + osname + " 3");

    await shell("cd " + workingDir + " && " + "bash vbox.sh startVM " + osname );

    core.info("First boot");
    


    await shell("cd " + workingDir + " && " + "bash vbox.sh waitForText " + osname + "'"+ loginTag +"'");


    let cmd1 = "mkdir -p /Users/runner/work && ln -s /Users/runner/work/  work";
    await execSSH(cmd1, "Setting up VM");

    let sync = core.getInput("sync");
    if (sync == "sshfs") {
      let cmd2 = "pkg_add sshfs-fuse && sshfs -o allow_other,default_permissions runner@10.0.2.2:work /Users/runner/work";
      await execSSH(cmd2, "Setup sshfs");
    } else {
      let cmd2 = "pkg_add rsync-3.2.3p0-iconv";
      await execSSH(cmd2, "Setup rsync-3.2.3p0-iconv");
      await shell("rsync -auvzrtopg  --exclude _actions/vmactions/openbsd-vm  /Users/runner/work/ openbsd:work");
    }

    core.info("OK, Ready!");

  }
  catch (error) {
    core.setFailed(error.message);
    await shell("cd " + workingDir + " && pwd && ls -lah" );
    await shell("bash -c 'pwd && ls -lah ~/.ssh/ && cat ~/.ssh/config'" );
  }
}



async function main() {
  let nat = core.getInput("nat");
  core.info("nat: " + nat);

  let mem = core.getInput("mem");
  core.info("mem: " + mem);

  await setup(nat, mem);

  var envs = core.getInput("envs");
  console.log("envs:" + envs);
  if (envs) {
    fs.appendFileSync(path.join(process.env["HOME"], "/.ssh/config"), "SendEnv " + envs + "\n");
  }

  var prepare = core.getInput("prepare");
  if (prepare) {
    core.info("Running prepare: " + prepare);
    await exec.exec("ssh -t openbsd", [], { input: prepare });
  }

  var run = core.getInput("run");
  console.log("run: " + run);

  try {
    var usesh = core.getInput("usesh").toLowerCase() == "true";
    if (usesh) {
      await exec.exec("ssh openbsd sh -c 'cd $GITHUB_WORKSPACE && exec sh'", [], { input: run });
    } else {
      await exec.exec("ssh openbsd sh -c 'cd $GITHUB_WORKSPACE && exec \"$SHELL\"'", [], { input: run });
    }
  } catch (error) {
    core.setFailed(error.message);
  } finally {
    let copyback = core.getInput("copyback");
    if(copyback !== "false") {
      let sync = core.getInput("sync");
      if (sync != "sshfs") {
        core.info("get back by rsync");
        await exec.exec("rsync -uvzrtopg  openbsd:work/ /Users/runner/work");
      }
    }
  }
}



main().catch(ex => {
  core.setFailed(ex.message);
});

