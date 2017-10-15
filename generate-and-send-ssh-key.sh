#!/bin/bash

# define settings here
KEYSIZE=2048
PASSPHRASE=
FILENAME=~/.ssh/id_test
KEYTYPE=rsa
HOST=host
USER=username

# add "-p <port>" if the ssh-server is listening on a different port
SSH_OPTS="-o PubkeyAuthentication=no"

#
# NO MORE CONFIG SETTING BELOW THIS LINE
#

# check that we have all necessary parts
SSH_KEYGEN=`which ssh-keygen`
SSH=`which ssh`
SSH_COPY_ID=`which ssh-copy-id`

if [ -z "$SSH_KEYGEN" ];then
    echo Could not find the 'ssh-keygen' executable
    exit 1
fi
if [ -z "$SSH" ];then
    echo Could not find the 'ssh' executable
    exit 1
fi

# perform the actual work
if [ -f $FILENAME ]
then
    echo Usig existing key
else
    echo Creating a new key using $SSH-KEYGEN
    $SSH_KEYGEN -t $KEYTYPE -b $KEYSIZE  -f $FILENAME -N "$PASSPHRASE"
    RET=$?
    if [ $RET -ne 0 ];then
        echo ssh-keygen failed: $RET
        exit 1
    fi
fi

echo Adjust permissions of generated key-files locally
chmod 0600 ${FILENAME} ${FILENAME}.pub
RET=$?
if [ $RET -ne 0 ];then
    echo chmod failed: $RET
    exit 1
fi

echo Copying the key to the remote machine $USER@$HOST, this should ask for the password
if [ -z "$SSH_COPY_ID" ];then
    echo Could not find the 'ssh-copy-id' executable, using manual copy instead
    cat ${FILENAME}.pub | ssh $SSH_OPTS $USER@$HOST 'cat >> ~/.ssh/authorized_keys'
else
	$SSH_COPY_ID $SSH_OPTS -i $FILENAME.pub $USER@$HOST
fi

RET=$?
if [ $RET -ne 0 ];then
    echo ssh-copy-id failed: $RET
    exit 1
fi

echo Adjusting permissions to avoid errors in ssh-daemon, this will ask once more for the password
$SSH $SSH_OPTS $USER@$HOST "chmod go-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-chmod failed: $RET
    exit 1
fi

# Cut out PubKeyAuth=no here as it should work without it now
echo Setup finished, now try to run $SSH `echo $SSH_OPTS | sed -e 's/-o PubkeyAuthentication=no//g'` -i $FILENAME $USER@$HOST
