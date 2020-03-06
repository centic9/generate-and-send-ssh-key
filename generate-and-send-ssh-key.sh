#!/bin/bash

# these are the defaults for the commandline-options
KEYSIZE=2048
PASSPHRASE=
FILENAME=~/.ssh/id_test
KEYTYPE=rsa
HOST=host
USER=${USER}

# use "-p <port>" if the ssh-server is listening on a different port
SSH_OPTS="-o PubkeyAuthentication=no"

#
# NO MORE CONFIG SETTING BELOW THIS LINE
#

function usage() {
	echo "Specify some parameters, valid ones are:"

    echo "  -u (--user)       <username>, default: ${USER}"
    echo "  -f (--file)       <file>,     default: ${FILENAME}"
    echo "  -h (--host)       <hostname>, default: ${HOST}"
    
    echo "  -p (--port)       <port>,     default: <default ssh port>"
    echo "  -k (--keysize)    <size>,     default: ${KEYSIZE}"
    echo "  -t (--keytype)    <type>,     default: ${KEYTYPE}"
    
    echo "  -P (--passphrase) <key-passphrase>, default: ${PASSPHRASE}"

    exit 2
}

if [[ $# < 1 ]]
then
	usage
fi

while [[ $# > 0 ]]
do
	key="$1"
	shift
	case $key in
		-u*|--user)
			USER="$1"
			shift
			;;
		-f*|--file)
			FILENAME="$1"
			shift
			;;
		-h*|--host)
			HOST="$1"
			shift
			;;
		-p*|--port)
			SSH_OPTS="${SSH_OPTS} -p $1"
			shift
			;;
		-k*|--keysize)
			KEYSIZE="$1"
			shift
			;;
		-t*|--keytype)
			KEYTYPE="$1"
			shift
			;;
		-P*|--passphrase)
			PASSPHRASE="$1"
			shift
			;;
		*)
			# unknown option
			usage "unknown parameter: $key, "
			;;
	esac
done

echo
echo "Transferring key from ${FILENAME} to ${USER}@${HOST} using options '${SSH_OPTS}', keysize ${KEYSIZE} and keytype: ${KEYTYPE}"
echo
echo "Press enter to continue or CTRL-C to abort"
read

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

echo
# perform the actual work
if [ -f $FILENAME ]
then
    echo Using existing key
else
    echo Creating a new key using $SSH-KEYGEN
    $SSH_KEYGEN -t $KEYTYPE -b $KEYSIZE  -f $FILENAME -N "$PASSPHRASE"
    RET=$?
    if [ $RET -ne 0 ];then
        echo ssh-keygen failed: $RET
        exit 1
    fi
fi

echo
echo Adjust permissions of generated key-files locally
chmod 0600 ${FILENAME} ${FILENAME}.pub
RET=$?
if [ $RET -ne 0 ];then
    echo chmod failed: $RET
    exit 1
fi

echo
echo Copying the key to the remote machine $USER@$HOST, this should ask for the password
if [ -z "$SSH_COPY_ID" ];then
    echo Could not find the 'ssh-copy-id' executable, using manual copy instead
    cat ${FILENAME}.pub | ssh $SSH_OPTS $USER@$HOST 'cat >> ~/.ssh/authorized_keys'
else
    $SSH_COPY_ID $SSH_OPTS -i $FILENAME.pub $USER@$HOST
    RET=$?
    if [ $RET -ne 0 ];then
      echo Executing ssh-copy-id via $SSH_COPY_ID failed, trying to manually copy the key-file instead
      cat ${FILENAME}.pub | ssh $SSH_OPTS $USER@$HOST 'cat >> ~/.ssh/authorized_keys'
    fi
fi

RET=$?
if [ $RET -ne 0 ];then
    echo ssh-copy-id failed: $RET
    exit 1
fi

echo
echo Adjusting permissions to avoid errors in ssh-daemon, this will ask once more for the password
$SSH $SSH_OPTS $USER@$HOST "chmod go-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-chmod failed: $RET
    exit 1
fi

# Cut out PubKeyAuth=no here as it should work without it now
echo
echo Setup finished, now try to run $SSH `echo $SSH_OPTS | sed -e 's/-o PubkeyAuthentication=no//g'` -i $FILENAME $USER@$HOST
