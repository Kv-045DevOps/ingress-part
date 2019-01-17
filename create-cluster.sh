#!/bin/bash
# aws s3api create-bucket --bucket k8s-storage-2 --region eu-central-1a --create-bucket-configuration LocationConstraint=eu-west-1

export NAME=cluster.k8s.local
export KOPS_STATE_STORE=s3://k8s-storage-2

kops create cluster --zones eu-central-1a --master-size=t2.micro --node-size=t2.micro ${NAME}
kops create secret --name cluster.k8s.local sshpublickey admin -i ./aws_k8s_key.pub
kops update cluster ${NAME} --yes
while [ 1 ]; do
    kops validate cluster && break || sleep 30
done;
./get_helm.sh
helm init --wait
kubectl apply -f kubectl/acc-helm.yml
helm install stable/cert-manager --wait
helm install --namespace kube-system --name nginx-ingress stable/nginx-ingress --set rbac.create=true --wait
kubectl apply -f kubectl/services.yml
kubectl apply -f kubectl/issuer.yml

export DOMAIN=cooki3.com
export GODADDY_KEY=
export GODADDY_SECRET=

aws route53 create-hosted-zone --name ${DOMAIN}. --caller-reference `date +%Y-%m-%d-%H:%M`
sleep 10
export LB_URL=`kubectl get svc -n kube-system | grep nginx-ingress-controller | tr -s ' ' | cut -d ' ' -f4`
envsubst < cname_template.json > cname.json
export ZONE_ID=`aws route53 list-hosted-zones --output text | grep -w ${DOMAIN}.|awk '{print $3}' | cut -d'/' -f3`
sleep 10
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://cname.json
aws route53 get-hosted-zone --id "$ZONE_ID" | jq '.DelegationSet.NameServers' > zone-ns.json
python3 set-ns.py
curl -X PUT -H "Authorization: sso-key $GODADDY_KEY:$GODADDY_SECRET" -H "Content-Type: application/json" -T domain-update.json "https://api.godaddy.com/v1/domains/$DOMAIN/records"
rm -f zone-ns.json domain-update.json

envsubst < kubectl/ingress2.yml > tmp.yml
kubectl apply -f tmp.yml
rm -f tmp.yml
