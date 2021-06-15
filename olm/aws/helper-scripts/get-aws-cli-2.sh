#!/bin/bash

echo "getting and setting up aws-cli-2"
dnf copr enable -y spot/aws-cli-2
dnf -y install aws-cli-2
