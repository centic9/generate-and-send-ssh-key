#!/bin/bash
# Requires at least BASH 4.0 

# these are the defaults for the commandline-options
KEYSIZE=2048
PASSPHRASE=
FILENAME=
KEYTYPE=rsa
HOST=
SSH_USER=
CERTONLY=
DIFF="None"
# use "-p <port>" if the ssh-server is listening on a different port
SSH_OPTS=
#"-o PubkeyAuthentication=no"

#
# NO MORE CONFIG SETTING BELOW THIS LINE
#

function usage() {
	echo "Specify some parameters, valid ones are:"
	echo
	echo "  -H (--help)                         This Info"
	echo
    echo "  -u (--user)       <username>,       default: ${SSH_USER}"
    echo "  -f (--file)       <file>,           default location: ~/.ssh/"
    echo "  -h (--host)       <hostname>,       default: ${HOST}"
	echo      
    echo "  -p (--port)       <port>,           default: <default ssh port>"
    echo "  -k (--keysize)    <size>,           default: ${KEYSIZE}"
    echo "  -t (--keytype)    <type>,           default: ${KEYTYPE}"
	echo
    echo "  -P (--passphrase) <key-passphrase>, default: ${PASSPHRASE}"
	echo "  -D (--disable-password),            disable password authentication for host"
	echo "  -o (--options)    <ssh-options>,    default: -o PubkeyAuthentication=no"
    exit 2
}

#if [[ $# < 1 ]];then
#	usage
#fi

while [[ $# > 0 ]]
do
	key="$1"
	shift
	case $key in
		-u*|--user)
			SSH_USER="$1"
			shift
			;;
		-f*|--file)
			if [[ "$1" == */* ]]; then
				echo using absolute path
				FILENAME="$1"
				echo ${FILENAME}
			else
				echo using relative path
				FILENAME="${HOME}/.ssh/$1"
			fi
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
		-D*|--disable-password)
			CERTONLY=true
			shift
			;;
		-o*|--options)
			SSH_OPTS="${SSH_OPTS} $1"
			shift
			;;
		-H|-help)
			usage 
			;;
		*)
			# unknown option
			usage "unknown parameter: $key, "
			;;
	esac
done

if [ -z ${HOST} ]; then 
	read -p "Enter Hostname to send the key to: " HOST
fi
if [ -z ${SSH_USER} ]; then
	read -e -p "Confirm to use current Username to connect to ${HOST}: " -i ${USER} SSH_USER
fi
if [ ${SSH_USER} != "root" ]; then
	while true; do
		read -p "You are not logging in with root(nothing wrong here), that means unless your login user is one of the sudoers, we most likely won't be able to perform any changes to the sshd server config. Shall we try anyway? (Y/N)" yn
		case $yn in
    	    [Yy]* ) 
				SUDOER=true
				break
				;;
    	    [Nn]* ) 
				SUDOER=false
				break
				;;
    	    * ) 
				echo "Please answer yes or no."
				;;
    	esac
	done
fi

if [ -z ${FILENAME} ]; then
	read -e -p "Enter filename for key: " -i "${HOME}/.ssh/id_${KEYTYPE}" FILENAME
fi

if [ -z ${CERTONLY} ]; then
	while true; do
		read -p "Shall we disable 'Password Authentication' for the server? (Y/N)" yn
		case $yn in
    	    [Yy]* ) 
				CERTONLY=true
				break
				;;
    	    [Nn]* ) 
				CERTONLY=false
				break
				;;
    	    * ) 
				echo "Please answer yes or no."
				;;
    	esac
	done
fi
echo
echo "Transferring key from ${FILENAME} to ${SSH_USER}@${HOST} using options '${SSH_OPTS}', keysize ${KEYSIZE} and keytype: ${KEYTYPE}"
echo
echo "Press ENTER to continue or CTRL-C to abort"
read

# check that we have all necessary parts
SSH_KEYGEN=`which ssh-keygen`
SSH=`which ssh`
SSH_COPY_ID=`which ssh-copy-id`

echo ${SSH_KEYGEN} ${SSH} ${SSH_COPY_ID}
if [ -z "${SSH_KEYGEN}" ];then
    echo Could not find the 'ssh-keygen' executable
    exit 1
fi
if [ -z "${SSH}" ];then
    echo Could not find the 'ssh' executable
    exit 1
fi

echo
# perform the actual work
if [ -f "${FILENAME}" ];then
    echo Using existing key
else
    echo Creating a new key using ${SSH_KEYGEN}
    ${SSH_KEYGEN} -t $KEYTYPE -b $KEYSIZE  -f "${FILENAME}" -N "${PASSPHRASE}"
    RET=$?
    if [ ${RET} -ne 0 ];then
        echo ssh-keygen failed: ${RET}
        exit 1
    fi
fi

if [ ! -f "${FILENAME}.pub" ];then
    echo Did not find the expected public key at ${FILENAME}.pub
    exit 1
fi

echo
echo Having key-information
ssh-keygen -l -f "${FILENAME}"

echo
echo Adjust permissions of generated key-files locally
chmod 0600 "${FILENAME}" "${FILENAME}.pub"
RET=$?
if [ ${RET} -ne 0 ];then
    echo chmod failed: ${RET}
    exit 1
fi

echo
echo Copying the key to the remote machine ${SSH_USER}@${HOST}, this should ask for the password
if [ -z "${SSH_COPY_ID}" ];then
    echo Could not find the 'ssh-copy-id' executable, using manual copy instead
    cat "${FILENAME}.pub" | ssh ${SSH_OPTS} ${SSH_USER}@${HOST} 'cat >> ~/.ssh/authorized_keys'
else
    ${SSH_COPY_ID} ${SSH_OPTS} -i ${FILENAME}.pub ${SSH_USER}@${HOST}
    RET=$?
    if [ ${RET} -ne 0 ];then
      echo Executing ssh-copy-id via ${SSH_COPY_ID} failed, trying to manually copy the key-file instead
      cat "${FILENAME}.pub" | ssh ${SSH_OPTS} ${SSH_USER}@${HOST} 'cat >> ~/.ssh/authorized_keys'
    fi
fi

RET=$?
if [ ${RET} -ne 0 ];then
    echo ssh-copy-id failed: ${RET}
    exit 1
fi

echo
echo Adjusting permissions to avoid errors in ssh-daemon
${SSH} ${SSH_OPTS} ${SSH_USER}@${HOST} "chmod go-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
RET=$?
if [ ${RET} -ne 0 ];then
    echo ssh-chmod failed: ${RET}
    exit 1
fi


if [ "$SUDOER" = true ]; then
	echo 
	echo "Looking on the host for the location of sshd_config."
	# Looking for non standard config file:
	remote_conf=`${SSH} ${SSH_OPTS} ${SSH_USER}@${HOST} 'ps aux |  grep -v "grep" | grep -som 1 -e "sshd.*-f.*"'`
	if [[ -z ${remote_conf} ]]; then
		# No config file option found, using default one
		remote_conf='/etc/ssh/sshd_config'
	else
		#Extracting config file path from response
		remote_conf=`echo ${remote_conf} | sed -e 's|.* -f ||' -e 's| .*||'`
	fi
	echo "Using following config file: ${remote_conf}"

	echo
	echo "Creating Backup of the original sshd_config file(${remote_conf}.bkp) on ${HOST}"

	${SSH} -t ${SSH_OPTS} ${SSH_USER}@${HOST} sudo -- 'cp '"${remote_conf}"' '"${remote_config}"'.bkp'
	RET=$?
	if [ ${RET} -ne 0 ];then
	    echo Could not copy config file: ${RET}
	    exit 1
	fi

	echo 
	echo Enabling Pubkey Authentication

	${SSH} -t ${SSH_OPTS} ${SSH_USER}@${HOST} sudo -- 'sed -i -E "s/^#?PubkeyAuthentication.*/PubkeyAuthentication=yes/" '"${remote_conf}"''
	RET=$?
	if [ ${RET} -ne 0 ];then
	    echo sed failed: ${RET}
	    exit 1
	fi
	DIFF="\nPubkeyAuthentication=yes\n"
	if [ "$CERTONLY" = true ]; then 
		echo
		echo Disabling password authentication
		${SSH} -t ${SSH_OPTS} ${SSH_USER}@${HOST} sudo -- 'sed -i -E "s/^#?PasswordAuthentication.*/PasswordAuthentication no/" '"${remote_conf}"''
		RET=$?
		if [ ${RET} -ne 0 ];then
		    echo sed failed: ${RET}
		    exit 1
		fi
		DIFF="${DIFF}PasswordAuthentication no\n"
	fi
fi

echo 
echo
echo ======================================= WORTH NOTING ============================================
echo "If it still does not work, you can try the following steps:"
echo "- Check if ~/.ssh/config has some custom configuration for this host"
echo "- Make sure the type of key is supported, e.g. 'dsa' is deprecated and might be disabled"
echo "- Try running ssh with '-v' and look for clues in the resulting output"
echo
echo "In any case, there is a backup of the original sshd_config file(${remote_conf}.bkp) on ${HOST}"
echo "Following changes were applied to the host sshd_config:"
echo -e ${DIFF}

echo "testing ssh connection now and logging in to ${HOST}. This should now be a passwordless login."
echo 
echo "                                          ! ! !"
echo 
echo "PLEASE check the sshd config at ${remote_conf} and reload the sshd daemon: Most probably via "
echo 
echo "                                 'sudo systemctl restart sshd'"
echo
echo ======================================= FINISHED ============================================
echo "press any key to continue"
read

${SSH} ${SSH_OPTS} ${SSH_USER}@${HOST}

echo "You are welcome!"