#!/bin/bash

exec > /home/ubuntu/userdata.log 2>&1

sudo apt-get update
echo "done with apt update"
sudo apt-get install apache2 -y
echo "done with apache2 install"
service apache2 status