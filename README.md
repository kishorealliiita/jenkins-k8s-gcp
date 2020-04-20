# Jenkins Master & Agents: using GKE to deploy Jenkins on Google Cloud.

For a more in depth best practices guide, go to the solution posted [here](https://cloud.google.com/solutions/jenkins-on-container-engine).

## Prerequisites
1. A Google Cloud Platform Account
1. [Enable the Compute Engine, Container Engine, and Container Builder APIs](https://console.cloud.google.com/flows/enableapi?apiid=compute_component,container,cloudbuild.googleapis.com)
2. Install gcloud - https://cloud.google.com/sdk/docs/quickstarts
3. Install kubectl - https://kubernetes.io/docs/tasks/tools/install-kubectl/
4. Install helm - https://helm.sh/docs/intro/install/


## Create cluster, deploy and install Jenkins.
You'll use Google Container Engine to create and manage your Kubernetes cluster. Provision the cluster with `gcloud`:

```shell
./deploy-jenkins-k8s.sh
```

## Install Helm

In this lab, you will use Helm to install Jenkins from the Charts repository. Helm is a package manager that makes it easy to configure and deploy Kubernetes applications.  Once you have Jenkins installed, you'll be able to set up your CI/CD pipleline.

1. Download and install the helm binary

    ```shell
    wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.1-linux-amd64.tar.gz
    ```

1. Unzip the file to your local system:

    ```shell
    tar zxfv helm-v2.14.1-linux-amd64.tar.gz
    cp linux-amd64/helm .
    ```

1. Add yourself as a cluster administrator in the cluster's RBAC so that you can give Jenkins permissions in the cluster:
    
    ```shell
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)
    ```

1. Grant Tiller, the server side of Helm, the cluster-admin role in your cluster:

    ```shell
    kubectl create serviceaccount tiller --namespace kube-system
    kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    ```

1. Initialize Helm. This ensures that the server side of Helm (Tiller) is properly installed in your cluster.

    ```shell
    ./helm init --service-account=tiller
    ./helm update
    ```

1. Ensure Helm is properly installed by running the following command. You should see versions appear for both the server and the client of ```v2.14.1```:

    ```shell
    ./helm version
    Client: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    ```

## Configure and use Jenkins

1. Run the following command to setup port forwarding to the Jenkins UI from the Cloud Shell

    ```shell
    export POD_NAME=$(kubectl get pods -l "app.kubernetes.io/component=jenkins-master" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $POD_NAME 8080:8080 >> /dev/null &
    ```

1. Now, check that the Jenkins Service was created properly:

    ```shell
    $ kubectl get svc
    NAME               CLUSTER-IP     EXTERNAL-IP   PORT(S)     AGE
    cd-jenkins         10.35.249.67   <none>        8080/TCP    3h
    cd-jenkins-agent   10.35.248.1    <none>        50000/TCP   3h
    kubernetes         10.35.240.1    <none>        443/TCP     9h
    ```

We are using the [Kubernetes Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Kubernetes+Plugin) so that our builder nodes will be automatically launched as necessary when the Jenkins master requests them.
Upon completion of their work they will automatically be turned down and their resources added back to the clusters resource pool.

Notice that this service exposes ports `8080` and `50000` for any pods that match the `selector`. This will expose the Jenkins web UI and builder/agent registration ports within the Kubernetes cluster.
Additionally the `jenkins-ui` services is exposed using a ClusterIP so that it is not accessible from outside the cluster.

## Connect to Jenkins

1. The Jenkins chart will automatically create an admin password for you. To retrieve it, run:

    ```shell
    printf $(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
    ```

2. To get to the Jenkins user interface, click on the Web Preview button![](../docs/img/web-preview.png) in cloud shell, then click “Preview on port 8080”:

![](docs/img/preview-8080.png)

You should now be able to log in with username `admin` and your auto generated password.

![](docs/img/jenkins-login.png)

### Your progress, and what's next
You've got a Kubernetes cluster managed by Google Container Engine. You've deployed:

* a Jenkins Deployment
* a (non-public) service that exposes Jenkins to its agent containers

You have the tools to build a continuous deployment pipeline. Now you need a sample app to deploy continuously.


## Clean up
Clean up is really easy, but also super important: if you don't follow these instructions, you will continue to be billed for the Google Container Engine cluster you created.

To clean up, navigate to the [Google Developers Console Project List](https://console.developers.google.com/project), choose the project you created for this lab, and delete it. That's it.
