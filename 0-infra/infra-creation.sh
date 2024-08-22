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

#!/bin/bash

# set to halt on execution errors and output the commands
set -ex

# load env vars file
source ./envs.sh

# sets up the default project where this infra will be deployed into
gcloud config set project prompt-privacy

# creates global ip address for moodle ingress controller (google cloud load balancer)
gcloud compute addresses create moodle-lb-ip --global

# enables networking services creation (if not enabled already)
gcloud services enable servicenetworking.googleapis.com \
  --project=prompt-privacy

# creates a new VPC (if not exists yet)
gcloud compute networks create my-moodle \
  --subnet-mode=custom \
  --bgp-routing-mode=regional \
  --mtu=1460

# creates a new subnet to support deployment of underlying services
gcloud compute networks subnets create moodle-subnet \
  --project=prompt-privacy \
  --range=10.20.0.0/16 \
  --stack-type=IPV4_ONLY \
  --network=my-moodle \
  --region=us-central1

# Create secondary ranges for the subnetwork to add to GKE
gcloud compute networks subnets update moodle-subnet \
  --region us-central1 \
  --add-secondary-ranges pod-range-gke-1=10.24.0.0/14

gcloud compute networks subnets update moodle-subnet \
  --region us-central1 \
  --add-secondary-ranges svc-range-gke-1=10.28.0.0/20

# enable container api
gcloud services enable container.googleapis.com \
  --project=prompt-privacy

# creates gke with necessary addons
gcloud container clusters create my-moodle-cluster \
  --release-channel=stable \
  --region=us-central1 \
  --enable-dataplane-v2 \
  --enable-ip-alias \
  --enable-private-nodes \
  --enable-private-endpoint \
  --enable-master-global-access \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=3 \
  --enable-autorepair \
  --monitoring=SYSTEM \
  --num-nodes=1 \
  --scopes=storage-rw,compute-ro \
  --enable-intra-node-visibility \
  --machine-type=n1-standard-2 \
  --network=my-moodle \
  --subnetwork=moodle-subnet \
  --addons=HttpLoadBalancing,HorizontalPodAutoscaling,GcpFilestoreCsiDriver \
  --logging=SYSTEM,WORKLOAD \
  --cluster-secondary-range-name=pod-range-gke-1 \
  --services-secondary-range-name=svc-range-gke-1

# grant minimal roles to the cluster service account
gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/monitoring.metricWriter

gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/monitoring.viewer

gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/logging.logWriter

gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/storage.objectViewer

gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/storage.objectAdmin

gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/artifactregistry.reader

gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/container.admin

# authorize cluster to be reached by some VM in the VPC (this will be needed later for cluster configuration)
gcloud container clusters update my-moodle-cluster \
  --enable-master-authorized-networks \
  --master-authorized-networks 192.168.1.0/24 \
  --region=us-central1

# creates a router and NAT config for enabling cluster's outbound communication
gcloud compute routers create moodle-standard-router \
    --project=prompt-privacy \
    --network=my-moodle \
    --asn=64512 \
    --region=us-central1

gcloud compute routers nats create moodle-standard-nat-config \
    --router=moodle-standard-router \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging \
    --region=us-central1

# defines an ip address range for vpc peering for mysql
gcloud compute addresses create my-moodle-managed-range-mysql \
  --global \
  --purpose=VPC_PEERING \
  --addresses=10.30.0.0 \
  --prefix-length=20 \
  --description="Moodle Range for MYSQL" \
  --network=my-moodle

# list addresses range created for vpc peering
gcloud compute addresses list --global --filter="purpose=VPC_PEERING"

# attach the range to the service networking API
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=my-moodle-managed-range-mysql \
  --network=my-moodle

# list vpc peering connections
gcloud compute networks subnets describe moodle-subnet \
--region us-central1 \
--project prompt-privacy

# creates cloud sql instance (managed)
gcloud sql instances create moodle-standard-instance \
  --database-version=MYSQL_8_0 \
  --cpu 1 \
  --memory 3840MB \
  --zone us-central1-a \
  --network=my-moodle \
  --retained-backups-count=7 \
  --enable-bin-log \
  --retained-transaction-log-days=7 \
  --maintenance-release-channel=production \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=08 \
  --availability-type=zonal \
  --storage-type=SSD \
  --storage-auto-increase \
  --storage-size=10GB \
  --retained-backups-count=7 \
  --backup-start-time=03:00 \
  --database-flags=character_set_server=utf8,default_time_zone=-03:00 \
  --root-password='oHcdi8H*oS&FZr@y'

# list cloud sql instances created
gcloud sql instances list

# creates cloud sql database with proper charset for moodle
gcloud sql databases create moodle \
  --instance moodle-standard-instance \
  --charset utf8mb4 \
  --collation utf8mb4_0900_ai_ci

# list cloud sql databases created
gcloud sql databases list --instance moodle-standard-instance

# creates memorystore redis (managed)
gcloud redis instances create my-moodle-redis \
  --size=1 \
  --network=my-moodle \
  --enable-auth \
  --maintenance-window-day=sunday \
  --maintenance-window-hour=08 \
  --redis-version=redis_6_x \
  --redis-config maxmemory-policy=allkeys-lru \
  --region=us-central1

# list redis instances created
gcloud redis instances list --region us-central1

# defines an ip address range for vpc peering for filestore
gcloud compute addresses create my-moodle-managed-range-filestore \
  --global \
  --purpose=VPC_PEERING \
  --addresses=10.3.0.0 \
  --prefix-length=24 \
  --description="Moodle Range for Filestore" \
  --network=my-moodle

# updates the peering connection adding both sql and filestore ranges
gcloud services vpc-peerings update \
  --service=servicenetworking.googleapis.com \
  --ranges=my-moodle-managed-range-mysql,my-moodle-managed-range-filestore \
  --network=my-moodle

# creates a filestore service for NFS support
gcloud filestore instances create my-moodle-filestore \
  --description="NFS to support Moodle data." \
  --tier=BASIC_SSD \
  --file-share="name=moodleshare,capacity=2.5TB" \
  --network="name=my-moodle,reserved-ip-range=my-moodle-managed-range-filestore,connect-mode=PRIVATE_SERVICE_ACCESS" \
  --zone=us-central1-a

# lists filestores available
gcloud filestore instances list

# enable artifact registry api if not enabled yet
gcloud services enable artifactregistry.googleapis.com

# create artifact registry repo for building Moodle images (you can skip it if you already have a repo for images)
gcloud artifacts repositories create moodle-filestore \
  --location=us-central1 \
  --repository-format=docker

# lists artifact registries available
gcloud artifacts repositories list

# grant access to cloud build to push images to artifact registry
gcloud projects add-iam-policy-binding prompt-privacy \
  --member serviceAccount:914571669166-compute@developer.gserviceaccount.com \
  --role roles/artifactregistry.writer

# create the jumpbox vm instance to manipulate the private GKE cluster on the same VPC
gcloud compute instances create vm-jumpbox-moodle \
  --project=prompt-privacy \
  --zone=us-central1-a \
  --machine-type=e2-micro \
  --network-interface=stack-type=IPV4_ONLY,subnet=moodle-subnet,no-address \
  --metadata=enable-oslogin=true \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account=914571669166-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name=vm-jumpbox-moodle,image=projects/debian-cloud/global/images/debian-12-bookworm-v20240312,mode=rw,size=10,type=projects/prompt-privacy/zones/us-central1-a/diskTypes/pd-balanced \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --reservation-affinity=any