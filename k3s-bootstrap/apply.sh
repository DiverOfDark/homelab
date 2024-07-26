kubectl apply -f argocd-ns.yaml
kubectl apply -f argocd.yaml -n argocd
kubectl apply -f metaapp.yaml -n argocd