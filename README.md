# encoder
simple shell utility which allow encoding and decoding texts and files, which can then be sent over unsecure network.

## Install
```bash
curl https://raw.githubusercontent.com/vivek-yadav/encoder/main/setup_encoder.sh | sh -
```
To force symlink update:
```bash
curl https://raw.githubusercontent.com/vivek-yadav/encoder/main/setup_encoder.sh | INSTALL_SYMLINK=force sh -
```

## Setup and test

1. Generate your certs
```bash
gen_my_keys
```

2. Test everything works
```bash
test_encode_decode
```

## Check your Public Key
Public keys are ment to be shared.
```bash
my_pub_key
```
You can share it with your friends, and ask them to add it using `add_others_key -p <your_name> -f "<your_public_key_file>"`

## Add others keys
```bash
add_others_key -p <person_name> -f "<person_public_pem_file>"
```
Or you can also directly provide the public key
```bash
add_others_key -p <person_name> -k "<person_public_pem_file_content"
```

## Encode
```bash
encode -p <person_name> -i <input_file> -o <encrypted_output_file> -k <encrypted_key_file>
```
Now transfer <encrypted_output_file>, <encrypted_key_file> to <person> over any network.

## Decode
```bash
decode -k <encrypted_key_file> -i <encrypted_file> -o <decrypted_file>
```
After decryption you can delete <encrypted_key_file>, <encrypted_file>.


