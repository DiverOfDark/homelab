#!/bin/bash
kubectl apply -f argocd-ns.yaml

helm template argocd -n argocd oci://ghcr.io/argoproj/argo-helm/argo-cd --version 7.3.11 -f .\argocd-values.yaml > argocd.yaml
kubectl apply -f argocd.yaml

kubectl apply -f metaapp.yaml -n argocd