##### kube-proxy
kube-proxy has a default value for --metrics-bind-address set to
"127.0.0.1:10249", this is unlikely to be corrected any time soon.  
the AWS kube-proxy add-on has the same default value.  

a workaround for this is:
```shell
kubectl --kubeconfig kubeconfig* -n kube-system get cm kube-proxy-config -o yaml |sed 's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249/' | kubectl --kubeconfig kubeconfig* apply -f -
kubectl --kubeconfig kubeconfig* -n kube-system patch ds kube-proxy -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"updateTime\":\"`date +'%s'`\"}}}}}"
```

a long term solution is a helm chart or some kind of patch applied through 
terraform.

##### grafana
grafana is configured with github login, with auto-login and logout menu disabled
github users don't have permission to modify dashboards or use explore mode

grafana generates a local admin password upon deployment
to get the admin password use:
```shell
kubectl get secret --namespace observability grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

afterwards you can
* login by with https://grafana.int.6cb06.xyz/login?disableAutoLogin
* map your github user to the Admin role
* and logout with https://grafana.int.6cb06.xyz/logout
