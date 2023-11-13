# eks cluster with ansible playbook installing helm nginx 
Steps 

    terraform init
    terraform plan ( dont forget to insert aws access key and secret key when prompted)
    terraform apply ( dont forget to insert aws access key and secret key when prompted)
this will spon up the cluster on aws 

next head to terminal and update your kubeconfig using 

    aws eks update-kubeconfig --name eks-project

then install chart using 

    ansible-playbook -i invnetory install_chart.yaml

this will spin up the nginx chart on to the cluster 

you can then test using kubectl commands such as 

-     kubectl get deployments
-     kubectl get pods
-     kubectl get service

to delete must first delete the deployment using

      kubectl delete deployment -name of deployment-

then the same with helm chart using 

-
-     helm uninstall revision name (in this case its nginx-revision) 

if not known you can also use helm history command to get the revision name

-     helm history    

then utimatley 

    teraform destory to destroy the cluster just created 

 
  
