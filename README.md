## What

This is a small script to perform all the tasks that are necessary to create a private/public keypair for 
ssh-authentication for password-less connecting to a remote server. Additionally it performs some checks and 
adjusts file-permissions both locally and on the remote server to avoid some common pitfalls.

## Why

Because I failed to remember how, every time I tried to do this manually.

## How

### Preconditions

You need to be able to connect to the remote server with a username and password.

### Grab it

    git clone git://github.com/centic9/generate-and-send-ssh-key.git

### Run it

The script expects some commandline arguments which specify which key should be transferred/created and 
where it should be sent to:

    -u (--user) <username>, default: $USER
    -f (--file) <file>,     default: ~/.ssh/id_test
    -h (--host) <hostname>, default: host
     
    -p (--port)    <port>, default: <default ssh port>
    -k (--keysize) <size>, default: 2048
    -t (--keytype) <type>, default: rsa
    
    -P(--passphrase) <key-passphrase>, default: <empty>

You should at least set `--user`, `--file`, and `--host`.  
If the key-file does not exist yet, a new key will be generated.

    cd generate-and-send-ssh-key
    ./generate-and-send-ssh-key.sh --user bob --host myhost

This will ask for the password of the target host at least once, probably twice, if the permissions are not set correctly yet.

### Enjoy

Now you should be able to connect to the machine via ```ssh -i $FILENAME $USER@$HOST```.  
If you use the filename 
```~/.ssh/id_rsa``` you can omit the "-i" argument to ssh.

## Support this project

If you find this tool useful and would like to support it, you can [Sponsor the author](https://github.com/sponsors/centic9)

## Caveat

This script will remove write access to your home-directory for "group" and "other" on the remote server because 
ssh-public/private key authentication will not work otherwise.  
So if there are processes running as different user, 
writing data to this directory may fail for them after this script is run.

## Related documents

* http://linux.die.net/man/1/ssh-copy-id
* https://en.wikipedia.org/wiki/Ssh-keygen
* http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man1/ssh-keygen.1?query=ssh-keygen&sec=1
* http://www.thegeekstuff.com/2008/11/3-steps-to-perform-ssh-login-without-password-using-ssh-keygen-ssh-copy-id/
* http://askubuntu.com/questions/4830/easiest-way-to-copy-ssh-keys-to-another-machine
* http://www.daveperrett.com/articles/2010/09/14/ssh-authentication-refused/

#### Licensing

   Copyright 2015-2019 Dominik Stadler

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
