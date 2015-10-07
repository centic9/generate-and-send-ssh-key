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
wich ssh-keygen && which ssh-copy-id && which ssh
RET=$?
if [ $RET -ne 0 ];then
    echo Could not find the required tools, needed are 'ssh', 'ssh-keygen', 'ssh-copy-id': $RET
    exit 1
fi

# perform the actual work
ssh-keygen -t $KEYTYPE -b $KEYSIZE  -f $FILENAME -N "$PASSPHRASE"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-keygen failed: $RET
    exit 1
fi

ssh-copy-id -i $FILENAME $USER@$HOST
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-copy-id failed: $RET
    exit 1
fi

ssh $USER@$HOST "chmod go-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-chmod failed: $RET
    exit 1
fi

echo Setup finished, now try to run ssh -i $FILENAME $USER/$HOST
