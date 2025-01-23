#!/usr/bin/env bash

SUBCONVERTER_VERSION=${SUBCONVERTER_VERSION:-0.9.0}
EXTRACTED_DIRECTORY=subconverter_release
SUBSCRIPTION_URL=${SUBSCRIPTION_URL:?what are you doing? there is no SUBSCRIPTION_URL}
GIST_TOKEN=${GIST_TOKEN:?what are you doing? there is no GIST_TOKEN}
GIST_ID=${GIST_ID:?what are you doing? there is no GIST_ID}

wget -O subconverter_release.tar.gz "https://github.com/tindy2013/subconverter/releases/download/v${SUBCONVERTER_VERSION}/subconverter_linux64.tar.gz"
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

[clash]
path=output.yaml
target=clash
url=${SUBSCRIPTION_URL}
upload=true
upload_path=clash
EOF

cat <<EOF > gistconf.ini
[common]
token = ${GIST_TOKEN}
id = ${GIST_ID}
EOF

./subconverter -g --artifact surfboard,clash --log out.tmp 