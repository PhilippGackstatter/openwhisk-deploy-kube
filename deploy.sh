DEPLOY_BRANCH=`git rev-parse --abbrev-ref HEAD`
OW_BRANCH=`git --git-dir=../openwhisk/.git rev-parse --abbrev-ref HEAD`

echo "openwhisk-deploy-kube HEAD is at $DEPLOY_BRANCH and openwhisk is at $OW_BRANCH."

if [[ "$(read -e -p 'Continue? [y/N]> '; echo $REPLY)" == [Nn]* ]]
then
    exit
fi

kind create cluster --config kind-cluster.yaml
INTERNALIP=`kubectl describe node kind-worker | grep InternalIP: | awk '{print $2}'`
yq -y .whisk.ingress.apiHostName=\"$INTERNALIP\" cluster-template.yaml > mycluster.yaml

kubectl label node kind-worker openwhisk-role=core
kubectl label node kind-worker2 openwhisk-role=invoker

# These images are built locally
kind load docker-image --nodes kind-worker,kind-worker2 whisk/invoker:latest
kind load docker-image --nodes kind-worker,kind-worker2 whisk/controller:latest
kind load docker-image --nodes kind-worker,kind-worker2 whisk/ow-utils

# These images are pulled from a registry
kind load docker-image --nodes kind-worker,kind-worker2 openwhisk/apigateway
kind load docker-image --nodes kind-worker,kind-worker2 apache/couchdb
# kind load docker-image --nodes kind-worker,kind-worker2 openwhisk/controller
# kind load docker-image --nodes kind-worker,kind-worker2 openwhisk/invoker
kind load docker-image --nodes kind-worker,kind-worker2 wurstmeister/kafka
kind load docker-image --nodes kind-worker,kind-worker2 zookeeper
kind load docker-image --nodes kind-worker,kind-worker2 nginx
kind load docker-image --nodes kind-worker,kind-worker2 redis
kind load docker-image --nodes kind-worker,kind-worker2 busybox
kind load docker-image --nodes kind-worker,kind-worker2 openwhisk/alarmprovider
kind load docker-image --nodes kind-worker,kind-worker2 openwhisk/kafkaprovider

helm install owdev ./helm/openwhisk -n openwhisk --create-namespace -f mycluster.yaml

wsk property set --apihost 127.0.0.1:31001