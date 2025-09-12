#!/usr/bin/env bash

# ApplicationSet
oc delete -n openshift-gitops apps 3scale cms-upload --wait=false &> /dev/null

# 3scale
if oc get namespace 3scale &>/dev/null; then
    oc get applicationauth -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get application.capabilities.3scale.net -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get developeraccount -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get developeruser -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get activedoc -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get proxyconfigpromote -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get product -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get backend -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get apimanager -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get custompolicydefinition -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc wait --for=delete apimanager/apimanager --timeout=60s

    oc get subscription -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    #oc get tektonresult -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get pipelinerun -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get taskrun -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get tasks -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale
    oc get eventlistener -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    # Delete any running pod from jobs
    for job in $(oc get job -n 3scale -l rhoai-example=maas -o name | cut -d '/' -f 2); do
        oc get pod -l "batch.kubernetes.io/job-name=$job" -n 3scale -o name | xargs oc patch -p '{"metadata":{"finalizers":[]}}' -n 3scale --type=merge
        oc get pod -l "batch.kubernetes.io/job-name=$job" -n 3scale -o name | xargs oc delete -n 3scale
    done

    oc get job -n 3scale -l rhoai-example=maas -o name | xargs oc patch -p '{"metadata":{"finalizers":[]}}' -n 3scale --type=merge
    oc get job -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    oc get rolebindings -n 3scale -l rhoai-example=maas -o name | xargs oc patch -p '{"metadata":{"finalizers":[]}}' -n 3scale --type=merge
    oc get rolebindings -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    oc get serviceaccount -n 3scale -l rhoai-example=maas -o name | xargs oc patch -p '{"metadata":{"finalizers":[]}}' -n 3scale --type=merge
    oc get serviceaccount -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    oc get secret -n 3scale -l rhoai-example=maas -o name | xargs oc patch -p '{"metadata":{"finalizers":[]}}' -n 3scale --type=merge
    oc get secret -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    oc get configmap -n 3scale -l rhoai-example=maas -o name | xargs oc patch -p '{"metadata":{"finalizers":[]}}' -n 3scale --type=merge
    oc get configmap -n 3scale -l rhoai-example=maas -o name | xargs oc delete -n 3scale

    oc delete namespace 3scale || true
fi
