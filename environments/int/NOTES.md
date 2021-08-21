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
