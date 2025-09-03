#!/usr/bin/env bash
set -euo pipefail

### Delete taskruns, pipelineruns, and any allocated PVCs for a given namespace

NAMESPACE="${1:-'3scale'}"


for i in $(kubectl get pipelinerun -n "$NAMESPACE" | grep 'Failed\|Succeeded' | cut -f 1 -d ' '); do
PVC=$(kubectl get pvc -n "$NAMESPACE" -o json | jq -r --arg i "$i" '.items[].metadata | select(.ownerReferences[0].name==$i)|.name')
if [ -z "$PVC" ]
then
  echo "$i's PVC was already removed"
else
  kubectl delete pvc -n "$NAMESPACE" $PVC &
fi
done

oc get pipelinerun -n "$NAMESPACE" -l rhoai-example=maas -o name | xargs oc delete -n "$NAMESPACE"
oc get taskrun -n "$NAMESPACE" -l rhoai-example=maas -o name | xargs oc delete -n "$NAMESPACE"
