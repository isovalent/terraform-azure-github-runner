#!/bin/bash -x
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

USER_NAME=${runner_username}
USER_ID=1000

sudo groupadd actions-runner -g $USER_ID
sudo useradd -u $USER_ID $USER_NAME -m -s /bin/bash -G sudo,docker,actions-runner -g $USER_NAME

# retrieve gh registration token from azure key vault
az login --identity --allow-no-subscription
export REGISTRATION_TOKEN=$(az keyvault secret show -n $(hostname) --vault-name ${registration_key_vault_name} | jq -r '.value')

sudo -b -i -u $${USER_NAME} --preserve-env=REGISTRATION_TOKEN <<EOF
cd /opt/actions-runner

./config.sh \
  --unattended \
  --ephemeral \
  --replace \
  --runnergroup ${runner_group} \
  --labels ${runner_labels} \
  --url https://github.com/${runner_owner} \
  --token $${REGISTRATION_TOKEN}

./run.sh
EOF
