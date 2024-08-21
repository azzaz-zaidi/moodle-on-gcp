# Copyright 2022 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#/bin/bash

# environment variables required for the infra-creation script to run
# make changes to your project, region, zone and networking resources
# ip ranges here described are suggestive and can be adjusted to fit production's needs

PROJECT_NUMBER=914571669166
PROJECT_ID=prompt-privacy
REGION=us-central1
ZONE=us-central1-a

VPC_NAME=my-moodle
SUBNET_NAME=moodle-subnet
SUBNET_RANGE=10.0.0.0/16

# gke specific variables
NODE_SA_EMAIL=914571669166-compute@developer.gserviceaccount.com
GKE_POD_RANGE=10.4.0.0/14
GKE_SVC_RANGE=10.8.0.0/20
GKE_MASTER_IPV4_RANGE=10.0.0.2/20

# cloud build specific variables
CLOUD_BUILD_SA_EMAIL=914571669166@cloudbuild.gserviceaccount.com

# if you have VMs in a different subnet, make sure to include it here, separated by comma (,)
MASTER_AUTHORIZED_NETWORKS=192.168.1.0/24

# peering ranges for managed services, such as cloud sql and filestore
MOODLE_MYSQL_MANAGED_PEERING_RANGE=10.2.0.0/20
MOODLE_FILESTORE_MANAGED_PEERING_RANGE=10.3.0.0/24

# NAT config
NAT_CONFIG=moodle-standard-nat-config
NAT_ROUTER=moodle-standard-router

# db specific variables
GKE_NAME=moodle-standard-cluster
MYSQL_INSTANCE_NAME=moodle-standard-instance
MYSQL_ROOT_PASSWORD='oHcdi8H*oS&FZr@y'
MYSQL_DB=moodle
MYSQL_MOODLE_DB_CHARSET=utf8mb4 #recommended collation for Moodle. Change only if necessary.
MYSQL_MOODLE_DB_COLLATION=utf8mb4_0900_ai_ci #recommended collation for Moodle. Change only if necessary.

# other managed services variables
REDIS_NAME=my-moodle-redis

FILESTORE_NAME=my-moodle-filestore
FILESTORE_MOUNT=/mnt/filestore1

# variables for config files and companion shell scripts

# you can change this to any instance name for your current instance, later you can change this
# if you plan to install a different instance, rename it to some different squad name, etc.
export MOODLE_ROOT_PATH=/moodleroot-instance1 
export MOODLE_ROOT_PATH_NO_SLASH=${MOODLE_ROOT_PATH/?}
MOODLE_ROOT_IN_FILESTORE=$FILESTORE_MOUNT/$MOODLE_ROOT_PATH_NO_SLASH
