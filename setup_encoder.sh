#!/bin/sh
set -e
set -o noglob
INSTALL_DIR=${INSTALL_DIR:=~/encoder}
mkdir -p ${INSTALL_DIR}
BIN_DIR=${BIN_DIR:=/usr/local/bin}
SYMLINK_SKIP=${SYMLINK_SKIP:=false}
# INSTALL_SYMLINK can have value force

MY_KEYS=${INSTALL_DIR}/my_keys

GEN_MY_KEYS_FILE=${INSTALL_DIR}/gen_my_keys
ADD_OTHERS_KEY_FILE=${INSTALL_DIR}/add_others_key
DECODE_FILE=${INSTALL_DIR}/decode
ENCODE_FILE=${INSTALL_DIR}/encode
MY_PUB_KEY_FILE=${INSTALL_DIR}/my_pub_key
TEST_ENCODE_DECODE_FILE=${INSTALL_DIR}/test_encode_decode


# --- helper functions for logs ---
info()
{
    echo '[INFO] ' "$@"
}
warn()
{
    echo '[WARN] ' "$@" >&2
}
fatal()
{
    echo '[ERROR] ' "$@" >&2
    exit 1
}

# Create gen_my_keys command
tee ${GEN_MY_KEYS_FILE} >/dev/null << EOF
#!/usr/bin/env bash
MY_KEYS_DIR=${INSTALL_DIR}/my_keys
mkdir -p \${MY_KEYS_DIR}

MY_PRI_KEY_FILE=\${MY_KEYS_DIR}/key.pem
if [[ ! -f "\$MY_PRI_KEY_FILE" ]]; then
    openssl genrsa -out \${MY_PRI_KEY_FILE} 1024 > /dev/null
    openssl rsa -in \${MY_PRI_KEY_FILE} -text -noout > /dev/null
else
    echo "\${MY_PRI_KEY_FILE} already exits"
fi

MY_PUB_KEY_FILE=\${MY_KEYS_DIR}/pub.pem
if [[ ! -f "\$MY_PUB_KEY_FILE" ]]; then
    openssl rsa -in \${MY_PRI_KEY_FILE} -pubout -out \${MY_PUB_KEY_FILE} > /dev/null
    openssl rsa -in \${MY_PUB_KEY_FILE} -pubin -text -noout > /dev/null
else
    echo "\${MY_PUB_KEY_FILE} already exits"
fi

chmod 400 \${MY_PRI_KEY_FILE}
chmod 400 \${MY_PUB_KEY_FILE}

EOF



# Create test_encode_decode command
tee ${TEST_ENCODE_DECODE_FILE} >/dev/null << EOF
#!/usr/bin/env bash

MY_KEYS_DIR=${INSTALL_DIR}/my_keys

echo "Test Encoding and Decoding"
openssl rand -base64 4096 > top_secret.txt

echo "On generator side:"
echo "1. generate symmetric key"
openssl rand -base64 32 > key.bin

echo "2. encrypt input file with symmetric key"
openssl enc -aes-256-cbc -salt -in top_secret.txt -out top_secret.enc -pass file:key.bin

echo "3. encypt symmetric key with private key"
openssl rsautl -encrypt -inkey \${MY_KEYS_DIR}/pub.pem -pubin -in key.bin -out key.bin.enc

echo "4. delete plain symmetric key"
rm key.bin

echo
echo "On receiver side:"
echo "1. decrypt symmetric key"
openssl rsautl -decrypt -inkey \${MY_KEYS_DIR}/key.pem -in key.bin.enc -out key.bin.dec

echo "2. decrypt encrypted file with decrypted symmetric key"
openssl enc -d -aes-256-cbc -in top_secret.enc -out top_secret.dec -pass file:key.bin.dec

diff top_secret.txt top_secret.dec
echo -n "Test Result: "
if [ \$? -eq 0 ]; then
   echo "PASS"
else
   echo "FAIL"
fi
rm top_secret.*
EOF



# Create decode command
tee ${DECODE_FILE} >/dev/null << EOF
#!/usr/bin/env bash
# command:
#    $ decode -i <encrypted_file> -o <destination_decoded_file> -k <encrypted_key_file>
#

MY_KEYS_DIR=${INSTALL_DIR}/my_keys

while getopts o:i:k: flag
do
    case "\${flag}" in
        o) outfile=\${OPTARG};;
        i) infile=\${OPTARG};;
        k) keyfile=\${OPTARG};;
    esac
done

if [[ -z "\$outfile" ]]; then
    echo "Please provde -o \"output_decrypted_file\""
    exit 1
fi

if [[ -z "\$infile" ]]; then
    echo "Please provde -i \"input_encrypted_file\""
    exit 2
fi

if [[ -z "\$keyfile" ]]; then
    echo "Please provde -k \"encrypted_key_file\""
    exit 3
fi

openssl rsautl -decrypt -inkey \${MY_KEYS_DIR}/key.pem -in \${keyfile} -out \${keyfile}.dec
openssl enc -d -aes-256-cbc -in \${infile} -out \${outfile} -pass file:\${keyfile}.dec
rm \${keyfile}.dec
EOF



# Create encode command
tee ${ENCODE_FILE} >/dev/null << EOF
#!/usr/bin/env bash
# command:
#    $ encode -p <person_name> -i <source_file> -o <encrypted_output_file>
#
OTHERS_KEYS_DIR=${INSTALL_DIR}/others_keys

while getopts o:i:p:k: flag
do
    case "\${flag}" in
        o) outfile=\${OPTARG};;
        i) infile=\${OPTARG};;
        p) person=\${OPTARG};;
        k) keyfile=\${OPTARG};;
    esac
done

if [[ -z "\$person" ]]; then
    echo "Please provde -p \"person_name\""
    exit 1
fi

if [[ -z "\$keyfile" ]]; then
    echo "Please provde -k \"key_file_name\""
    exit 2
fi

if [[ -z "\$infile" ]]; then
    echo "Please provde -i \"input_file_name\""
    exit 3
fi

if [[ -z "\$outfile" ]]; then
    echo "Please provde -o \"output_file_name\""
    exit 4
fi

openssl rand -base64 32 > \${keyfile}.bin
openssl enc -aes-256-cbc -salt -in \${infile} -out \${outfile} -pass file:\${keyfile}.bin
openssl rsautl -encrypt -inkey \${OTHERS_KEYS_DIR}/\${person}.pub.pem -pubin -in \${keyfile}.bin -out \${keyfile}
rm \${keyfile}.bin
echo "\${outfile} is the encrypted input file"
echo "\${keyfile} is the encrypted key"
echo "Please share both these files to \${person}"
echo "and ask them to run this to decode:"
echo "     $ decode -k \${keyfile} -i \${outfile} -o \${outfile}.dec"
EOF



# Create my_pub_key command
tee ${MY_PUB_KEY_FILE} >/dev/null << EOF
#!/usr/bin/env bash
MY_KEYS_DIR=${INSTALL_DIR}/my_keys
cat \${MY_KEYS_DIR}/pub.pem
EOF



# Create add_others_key command
tee ${ADD_OTHERS_KEY_FILE} >/dev/null << EOF
#!/usr/bin/env bash
# command:
# opton 1:
#   $ add_others_key -p vivek -f "vivek.pub.pem"
#
# option 2:
#   $ add_others_key -p vivek1 -k "-----BEGIN PUBLIC KEY-----
#     MIGfMA0G....pGzOvGiPwy3ZxSZ
#     mWvd1II9LFu1PxYnHQIDAQAB
#     -----END PUBLIC KEY-----"

while getopts f:p:k: flag
do
    case "\${flag}" in
        f) pubkeyfile=\${OPTARG};;
        p) person=\${OPTARG};;
        k) pubkey=\${OPTARG};;
    esac
done
OTHERS_KEYS_DIR=${INSTALL_DIR}/others_keys
mkdir -p \${OTHERS_KEYS_DIR}
if [ -z "\${pubkey}" ]
then
    cp \${pubkeyfile} \${OTHERS_KEYS_DIR}/\${person}.pub.pem
else
    echo -e "\${pubkey}" > \${OTHERS_KEYS_DIR}/\${person}.pub.pem
fi

chmod 400 \${OTHERS_KEYS_DIR}/\${person}.pub.pem
EOF




# --- add additional utility links ---
create_symlinks() {
    [ "${SYMLINK_SKIP}" = true ] && return

    for cmd in add_others_key decode encode gen_my_keys my_pub_key test_encode_decode; do
        if [ ! -e ${BIN_DIR}/${cmd} ] || [ "${INSTALL_SYMLINK}" = force ]; then
            which_cmd=$(command -v ${cmd} 2>/dev/null || true)
            if [ -z "${which_cmd}" ] || [ "${INSTALL_SYMLINK}" = force ]; then
                info "Creating ${BIN_DIR}/${cmd} symlink to encode"
                # --- use sudo if we are not already root ---
                SUDO=sudo
                if [ $(id -u) -eq 0 ]; then
                    SUDO=
                fi
                $SUDO ln -sf ${INSTALL_DIR}/${cmd} ${BIN_DIR}/${cmd}
                chmod +x ${INSTALL_DIR}/${cmd}
            else
                info "Skipping ${BIN_DIR}/${cmd} symlink to encode, command exists in PATH at ${which_cmd}"
            fi
        else
            info "Skipping ${BIN_DIR}/${cmd} symlink to encode, already exists"
        fi
    done
}

create_symlinks

info "To test everything is ready, run this command:"
info "           $ test_encode_decode"
