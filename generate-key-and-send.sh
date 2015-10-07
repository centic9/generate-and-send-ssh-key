#!/bin/bash

KEYSIZE=2048
PASSPHRASE=
FILENAME=~/.ssh/id_test
KEYTYPE=rsa
HOST=host
USER=username

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
