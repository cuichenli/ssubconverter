#!/usr/bin/env bash

SUBCONVERTER_VERSION=${SUBCONVERTER_VERSION:-0.9.8}
EXTRACTED_DIRECTORY=subconverter_release
SUBSCRIPTION_URL=${SUBSCRIPTION_URL:?what are you doing? there is no SUBSCRIPTION_URL}
GIST_TOKEN=${GIST_TOKEN:?what are you doing? there is no GIST_TOKEN}
GIST_ID=${GIST_ID:?what are you doing? there is no GIST_ID}

wget -O subconverter_release.tar.gz "https://github.com/asdlokj1qpi233/subconverter/releases/download/v${SUBCONVERTER_VERSION}/subconverter_linux64.tar.gz"
tar xvf ./subconverter_release.tar.gz 

mv ./subconverter "./${EXTRACTED_DIRECTORY}"
cp "./${EXTRACTED_DIRECTORY}/subconverter" .
cp -r "./${EXTRACTED_DIRECTORY}/base" ./base

cat <<EOF > generate.ini
[surfboard]
path=output.yaml
target=surfboard
url=${SUBSCRIPTION_URL}
upload=true
upload_path=surfboard
udp=true

[clash]
path=output.yaml
target=clash
url=${SUBSCRIPTION_URL}
upload=false
upload_path=clash
udp=true

[singbox]
path=output.yaml
target=singbox
url=${SUBSCRIPTION_URL}
upload=false
upload_path=singbox
udp=true
EOF

cat <<EOF > gistconf.ini
[common]
token = ${GIST_TOKEN}
id = ${GIST_ID}
EOF

./subconverter -g --artifact surfboard --log out-surfboard.tmp 
./subconverter -g --artifact clash --log out-clash.tmp 
./subconverter -g --artifact singbox --log out-singbox.tmp 