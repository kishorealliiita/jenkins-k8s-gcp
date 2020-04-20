#!/bin/bash
trap "exit 1" TERM
export TOP_PID=$$

#-------------------------------------------------------------------------------
# Function Definitions
#-------------------------------------------------------------------------------
function usage()
{
  cat <<EOU >&2

Usage: $(basename ${BASH_SOURCE[0]} .sh) [-?/-h]

Options:

Environment Variable Overrides:
  REGION        : Set gcp region ( default: australia-southeast1 )
  PROJECT          : Set GCP project ( default adimin-project )

EOU
  exit
}

function log()
{
  echo "`TZ=Australia/Melbourne date  +%Y/%m/%d-%H:%M:%S` : $@"
}

function warn() {
  log "WARNING - $@" >& 2
}

function die()
{
  log "FATAL - $@"
  kill -s TERM ${TOP_PID}
}

function createK8sCluster() {
    gcloud compute networks create k8-jenkins --subnet-mode auto
    gcloud container clusters create jenkins \
      --node-labels=application=jenkins,function=multicloud-deploy \
      --network k8-jenkins
    gcloud container clusters list
    gcloud container clusters get-credentials jenkins
    kubectl cluster-info
    log "INFO - $@" >& 2
}

function downLoadHelm()
{
    HELM_VERSION=2.9.1
    wget https://storage.googleapis.com/kubernetes-helm/helm-v$HELM_VERSION-linux-amd64.tar.gz
    tar zxfv helm-v$HELM_VERSION-linux-amd64.tar.gz
    cp linux-amd64/helm .
}

function createServieAccount()
{
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)
    kubectl create serviceaccount tiller --namespace kube-system
    kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

    kubectl apply -f rbac_helm.yaml
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
    helm repo update
}

function installJenkins()
{
    # Give tiller a chance to start up
    until helm version; do sleep 10;done

    helm install cd-jenkins stable/jenkins -f jenkins/values.yaml --wait

    for i in `seq 1 5`;do kubectl get pods; sleep 60;done

    until kubectl get pods -l app=cd-jenkins | grep Running; do sleep 10;done
}

function cleanup()
{
    helm delete cd-jenkins
    gcloud container clusters delete jenkins
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
REGION=${GCP_REGION:-us-central1-c}
PROJECT=${GCP_PROJECT:-k8-test-274804}

log "FCP Region            - ${REGION}"
log "Project       - ${PROJECT}"
echo; echo 

gcloud config set compute/zone $REGION
createK8sCluster
#brew install helm --> for mac and comment below line.
#downLoadHelm
createServieAccount
installJenkins
#comment below line if you want to use the cluser.
#cleanup