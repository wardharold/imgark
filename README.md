# Project Title

**imgark** is a simple kubernetes application that demonstrates how to use per pod Google Cloud Platform
service accounts to enforce a least privilege policy for accessing Google Cloud Platform services.

## Getting Started

These instructions will get you a copy of the project built and deployed in your own Google Cloud Platform project.

### Prerequisites

In addition to a Google Cloud Platform account and project you'll need the following tools

Hashicorp's Terraform
```
Download the lastest version from: https://www.terraform.io/downloads.html
Unzip it and add the terraform binary to your path
```
Kubernetes Helm
```
Download the latest version from: https://github.com/helm/helm/releases
Untar it and add the helm binary to your path
```
Helm ChartMuseum
```
curl -LO https://s3.amazonaws.com/chartmuseum/release/latest/bin/linux/amd64/chartmuseum
Add the chartmuseum binary to your path
```

### Installing

In your chosen project use terraform to create service accounts, least privilege policies, and a GKE cluster.

```
cd deploy/tf
terraform plan -var project=$(gcloud config get-value core/project) -var cluster_name=<name-of-the-cluster>
terraform apply -var project=$(gcloud config get-value core/project) -var cluster_name=<name-of-the-cluster>
cd ../..
```

Now start chartmuseum and add it to helm's list of repos

```
mkdir -p ~/.local/share/charts
chartmuseum --debug --port=8888 --storage="local" --storage-local-rootdir=~/.local/share/charts &
helm repo add chartmuseum http://localhost:8888
```

Initialize helm in your cluster
```
gcloud container clusters get-credentials <name-of-the-cluster>
kubectl apply -f deploy/helm/tiller-rbac.yaml
helm init --service-account tiller
```

Finally, you build the container images and charts
```
make
```

## Deployment

To deploy **imgark** to your cluster
```
export IMAGE_BUCKET="$(gcloud config get-value core/project)-images"
gsutil mb gs://${IMAGE_BUCKET}
bin/deploy.sh -a archiver-service-account -l labeler-service-account -r receiver-service-account -b ${IMAGE_BUCKET} -t "cat,dog"
```

After a successful deployment ```kubectl get po``` should yield something that looks like:
```
NAME                                        READY     STATUS    RESTARTS   AGE
imgark-backend-labeler-659b947c78-7vvhj     1/1       Running   0          57m
imgark-cats-archiver-bfdf8647f-jktsv        1/1       Running   1          57m
imgark-dogs-archiver-6b4fc69bb5-w6fcg       1/1       Running   0          57m
imgark-frontend-receiver-b5cd585b6-4lkrl    1/1       Running   0          57m
imgark-leopards-archiver-7bbc68cf56-brcjt   1/1       Running   1          57m
```

## Operation

**imgark** accepts image files over HTTP, sends them off to be labeled with the Google Vision API, and then 
stores them in the designated image bucket if the one of the top three labels matches one of the specified
target labels.

To test it out download your favorite cat or dog image(s) and send them to the imgark receiver
```
export RECEIVER_POD=$(kubectl get po -l app=receiver -o jsonpath='{.items[*].metadata.name}'
kubectl port-forward ${RECEIVER_POD} 8889:8080 &
curl -v -F "file=@<path-to-image>" http://localhost:8889/receive
```
If the Google Vision API thinks the image you uploaded was a cat or dog it should appear in the image bucket
```
gsutil ls gs://${IMAGE_BUCKET}
```

## Built With

* [golang](https://golang.org) - The Go programming language
* [terraform](https://www.terraform.io/) - Infrastructure deployment
* [kubernetes](https://kubernetes.io/) - Container orchestrator

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE.md](LICENSE.md) file for details

