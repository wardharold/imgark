#!/usr/bin/env bash

DEFAULT_SVCACCT=$(gcloud iam service-accounts list | grep -i 'kubernetes engine default service account' | awk '{print $NF}')
PROJID=$(gcloud config get-value project)

ARCHIVER_SVCACCT=$DEFAULT_SVCACCT
LABELER_SVCACCT=$DEFAULT_SVCACCT
RECEIVER_SVCACCT=$DEFAULT_SVCACCT
BUCKET=
TARGETS=

usage()
{
    echo "usage: $0 [-alr] -b bucket -t targets"
}

while [ "$1" != "" ]; do
    case $1 in
        -b | --bucket)
            shift
            BUCKET=$1
            ;;
        -a | --archiver)
            shift
            ARCHIVER_SVCACCT=$1
            ;;
        -l | --labeler)
            shift
            LABELER_SVCACCT=$1
            ;;
        -r | --receiver)
            shift
            RECEIVER_SVCACCT=$1
            ;;
        -t | --targets)
            shift
            TARGETS=$1
            ;;
        -h | --help)
            usage
            exit
            ;;
        * )
            usage
            exit 1
    esac
    shift
done

[ -z $BUCKET ] || [ -z $TARGETS ] && (usage; exit 1)

[[ ! $(kubectl get ns/image-store 2> /dev/null) ]] && kubectl create namespace image-store
helm install stable/minio --name image-store --namespace image-store \
    --set persistence.enabled=false \
    --set networkPolicy.enabled=true \
    --set serviceType=ClusterIP

[[ ! $(kubectl get secrets/image-store-minio 2> /dev/null) ]] && kubectl --namespace image-store get secrets/image-store-minio --output json | jq '.metadata.namespace = "default"' | kubectl create -f -
# [ $? eq 0 ] || (echo "couldn't copy minio secret"; exit 1)

helm install chartmuseum/receiver --name imgark-frontend \
    --set image.repository="gcr.io/${PROJID}/receiver" \
    --set projectId=${PROJID} \
    --set serviceAccount=${RECEIVER_SVCACCT}@${PROJID}.iam.gserviceaccount.com

helm install chartmuseum/labeler --name imgark-backend \
    --set image.repository="gcr.io/${PROJID}/labeler" \
    --set projectId=${PROJID} \
    --set serviceAccount=${LABELER_SVCACCT}@${PROJID}.iam.gserviceaccount.com

for target in $(echo $TARGETS | tr ',' ' '); do
    helm install chartmuseum/archiver --name imgark-${target}s \
        --set image.repository="gcr.io/${PROJID}/archiver" \
        --set projectId=${PROJID} \
        --set serviceAccount=${ARCHIVER_SVCACCT}@${PROJID}.iam.gserviceaccount.com \
        --set bucket=$BUCKET \
        --set targetLabel=$target
done
