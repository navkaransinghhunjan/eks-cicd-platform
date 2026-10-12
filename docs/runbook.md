# Runbook

## Where did a deploy go wrong?
```bash
tail -n 20 logs/install.log                                   # repo copy
aws s3 cp s3://$LOGS_BUCKET/install.log - | tail -n 20        # source of truth
aws s3api list-object-versions --bucket $LOGS_BUCKET --prefix install.log  # history
```
Each line carries the GitHub `run=` id → open `https://github.com/<repo>/actions/runs/<id>`.

## Roll back
`--atomic` already rolls back a failed rollout. To revert a *successful* but bad release:
```bash
helm history eks-demo -n eks-demo
helm rollback eks-demo <REVISION> -n eks-demo --wait
STATUS=success IMAGE_TAG=rollback-to-rev-<REVISION> LOGS_BUCKET=$LOGS_BUCKET scripts/log-deploy.sh
```
Then revert the commit on `main` so Git matches the cluster.

## Pods not becoming ready
```bash
kubectl -n eks-demo get pods,events --sort-by=.lastTimestamp
kubectl -n eks-demo describe pod <pod>
kubectl -n eks-demo logs <pod> --previous
```

## Tear down (stop billing)
Actions → **infra** → Run workflow → `destroy` (needs `infra` approval), or locally:
```bash
helm uninstall ingress-nginx -n ingress-nginx   # removes the NLB first
terraform -chdir=terraform destroy
```
