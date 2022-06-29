---
title: 핸즈온. 쿠버네티스 환경 구성(local) - Kind
description: Kind로 로컬 쿠버네티스 환경을 구성하고 애플리케이션을 배포 해보는 실습
image: https://raw.githubusercontent.com/cloudacode/hello-kubernetes/main/docs/assets/kubernetes-school.png
---

# 핸즈온. 쿠버네티스 환경 구성(local) - Kind

**Kind 환경 구성 및 애플리케이션 배포 실습**

이번 실습은 Local 환경에서 Kind로 쿠버네티스 실습 환경을 만들고 애플리케이션을 배포 해보는 실습 입니다. 로컬 환경에서 컨테이너 서비스 배포를 위한 기본 작업들을 이해 할 수 있습니다.

## 사전 준비 사항

### Kuberctl 설치

kuberctl 설치: [관련 링크](https://kubernetes.io/docs/tasks/tools/)

### Docker Desktop 설치

Docker Desktop 설치: [관련 링크](https://docs.docker.com/desktop/)

!!! tip 
    윈도우를 사용하는 경우는 `WSL` 기능을 활성화 하여 리눅스 워크스페이스에서 도커를 사용 하는 것을 추천 한다.

    [WSL 설치 가이드](https://docs.microsoft.com/ko-kr/windows/wsl/install)
    ![wsl2](https://docs.docker.com/desktop/windows/images/wsl2-enable.png)

## Architecture
![Architecture](../assets/kind-architecture-cncf19.png)
Kind(`K`ubernetes `IN` `D`ocker)는 쿠버네티스 클러스터의 기능들을 테스트할 수 있도록 컨트롤러, 워커 노드의 컴포넌트들을 패키징 및 Image화 한 도커 컨테이너이다.

참고: [Kind Document - Initial design](https://kind.sigs.k8s.io/docs/design/initial/), [Deep Dive: Kind - CNCF19](https://youtu.be/tT-GiZAr6eQ?t=133)

## 1. Kind 구성 하기

### 설치

[Kind Document - Installation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

OS 패키지 매니저 혹은 바이너리를 통해서 설치를 진행

### Cluster 설정

Kind Cluster의 구성 정보를 코드화하여 관리할 수 있으며 여러 가지 기능들을 활성화할 수 있다. 원활한 실습을 위해 local cluster를 아래와 같이 컨트롤러 1개, 워커노드 3개로 클러스터를 구성하며 외부에서 ingress로 접근할 수 있도록 port mapping까지 기능을 활성화한다.

kind-cluster-config.yaml
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
# 1 control plane node and 3 workers
nodes:
# the control plane node config
- role: control-plane
  # create cluster with extraPortMappings
  # https://kind.sigs.k8s.io/docs/user/ingress/#create-cluster
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
- role: worker

```

참고: [configuring your kind cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#configuring-your-kind-cluster), [kind example config file](https://raw.githubusercontent.com/kubernetes-sigs/kind/main/site/content/docs/user/kind-example-config.yaml)

### Cluster 생성

정의한 구성 정보(kind-cluster-config.yaml) 대로 cluster 생성
```
$ kind create cluster --config kind-cluster-config.yaml 
```

### Kind Cluster 접속 확인

정상적인 output
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.24.0) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind
...
```

kubectl을 통해 추가된 node 확인
```
$ kubectl get nodes
NAME                 STATUS   ROLES           AGE     VERSION
kind-control-plane   Ready    control-plane   10m     v1.24.0
kind-worker          Ready    <none>          10m     v1.24.0
kind-worker2         Ready    <none>          10m     v1.24.0
kind-worker3         Ready    <none>          10m     v1.24.0
```

## 2. 애플리케이션 배포

### Nginx 워크로드 배포

대표적인 Stateless 애플리케이션인 Nginx를 쿠버네티스 환경에 배포하고 서비스 및 인그레스까지 연동하여 접근 확인을 해 본다.

!!! INFO
    Service, Ingress는 기초적인 설정으로 진행, 추후 별도 실습에서 자세히 다룰 예정

frontend-nginx.yaml
```yaml
kind: Pod
apiVersion: v1
metadata:
  name: frontend
  labels:
    app: nginx
spec:
  containers:
  - image: nginx
    name: nginx
    ports:
    - containerPort: 80
---
kind: Service
apiVersion: v1
metadata:
  name: frontend-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: front-ingress
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: frontend-service
            port:
              number: 80
---
```

정의된 구성대로 워크로드를 배포:
```bash
kubectl apply -f frontend-nginx.yaml
```

배포가 정상적으로 완료가 되면 Pod 정보를 찾을수 있다
```bash
kubectl get pods -l app=nginx
```

### 접근 확인

Service 타입을 기본 ClusterIP로 두고 외부 노출을 Ingress를 통해 하였으므로 다음과 같이 Endpoint를 Ingress 레벨에서 확인 가능
```bash
kubectl get ingress
```

Output
```bash
NAME               CLASS    HOSTS   ADDRESS     PORTS   AGE
frontend-ingress   <none>   *       localhost   80      68s
```

Endpoint [localhost:80](http://localhost:80) 접근 확인 및 브라우져로 기본 Nginx 페이지가 정상적으로 보이는지 확인

## Clean Up
실습 완료 후 kind cluster 삭제
```
kind delete cluster
```
