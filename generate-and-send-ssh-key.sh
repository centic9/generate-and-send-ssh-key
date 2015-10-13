#!/bin/bash

# define settings here
KEYSIZE=2048
PASSPHRASE=
FILENAME=~/.ssh/id_test
KEYTYPE=rsa
HOST=host
USER=username

#
# NO MORE CONFIG SETTING BELOW THIS LINE
#

# check that we have all necessary parts
SSH_KEYGEN=`which ssh-keygen`
SSH=`which ssh`
SSH_COPY_ID=`which ssh-copy-id`
if [ -z "$SSH_KEYGEN" -o -z "$SSH" -o -z "$SSH_COPY_ID" ];then
    echo Could not find the required tools, we need 'ssh', 'ssh-keygen', 'ssh-copy-id': $RET
    exit 1
fi

# perform the actual work
echo Creating a new key using $SSH-KEYGEN
$SSH_KEYGEN -t $KEYTYPE -b $KEYSIZE  -f $FILENAME -N "$PASSPHRASE"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-keygen failed: $RET
    exit 1
fi

echo Adjust permissions of generated key-files locally
chmod 0600 ${FILENAME}*
RET=$?
if [ $RET -ne 0 ];then
    echo chmod failed: $RET
    exit 1
fi

echo Copying the key to the remote machine $USER@$HOST
$SSH_COPY_ID -i $FILENAME $USER@$HOST
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-copy-id failed: $RET
    exit 1
fi

echo Adjusting permissions to avoid errors in ssh-daemon
$SSH $USER@$HOST "chmod go-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-chmod failed: $RET
    exit 1
fi

echo Setup finished, now try to run ssh -i $FILENAME $USER@$HOST
