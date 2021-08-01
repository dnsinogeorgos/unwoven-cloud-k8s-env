#!/bin/bash

set -e

export COLOR_RESET='\e[0m'
export COLOR_LIGHT_GREEN='\e[0;49;32m'

cp kubeconfig_* ~/.kube/config
chmod 0600 ~/.kube/config

kubectl apply -f ../../manifests/eks-admin-service-account.yaml
echo ""

SECRET_RESOURCE=$(kubectl get secrets -n kube-system -o name | grep eks-admin)
ENCODED_TOKEN=$(kubectl get $SECRET_RESOURCE -n kube-system -o=jsonpath='{.data.token}')
export TOKEN=$(echo $ENCODED_TOKEN | base64 --decode)
echo ""
WSL_IP=$(ip a show dev eth0 | grep "inet " | tr -s " " | cut -d " " -f 3 | sed 's/\/28//')
echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:443/proxy/#/login"
#echo "http://$WSL_IP:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:443/proxy/#/login"
echo ""
echo "--- Copy and paste this token for dashboard access ---"
echo -e $COLOR_LIGHT_GREEN
echo -e $TOKEN
echo -e $COLOR_RESET

kubectl proxy
