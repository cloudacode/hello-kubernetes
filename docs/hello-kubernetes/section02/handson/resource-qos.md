---
title: 핸즈온 2.2 Resources & QoS
description: 쿠버네티스 환경에서 ingress-nginx 구성 및 Ingress를 통해 Service에 접근을 해보는 실습
image: https://raw.githubusercontent.com/cloudacode/hello-kubernetes/main/docs/assets/kubernetes-school.png
---

# 핸즈온 2.2 Resources & QoS

Pod의 resource(cpu, mem)를 지정하여 QoS설정하는 실습

## 사전 준비 사항

Kind Kubernetes Cluster 구성: [실습 링크](../../section01/handson/setup-local-k8s-kind.md)

Helm의 이해: [관련 링크](../../section01/what-is-helm.md)

Helm 설치 및 애플리케이션 배포 방법: [실습 링크](../../section01/handson/setup-redis-via-helm.md)

## 1.Pod spec에 Requests와 Limits 지정하여 QoS별 Pod을 생성

### 1.1 Best-Effort Pod 생성하기
* resource requests/limits가 지정하지 않은 경우에 Best-Effort로 생성되기 때문에 지정하기 않고 생성한다.

* Pod specification yaml 작성
```bash
# namespace 생성
kubectl create ns qos-example

# yaml 생성
cat <<EOF > qos-demo-besteffort.yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo-besteffort
  namespace: qos-example
spec:
  containers:
  - name: qos-demo-ctr
    image: nginx
    resources:
      limits: {}
      requests: {}
EOF
```

* pod 생성 및 QoS 확인
```bash
kubectl apply -f qos-demo-besteffort.yaml
pod/qos-demo-besteffort created

kubectl get po -n qos-example
NAME       READY   STATUS    RESTARTS   AGE
qos-demo-besteffort   1/1     Running   0          26s

# QoS 확인
kubectl get po -n qos-example qos-demo-besteffort -o yaml
apiVersion: v1
kind: Pod
metadata:
  ...
spec:
  containers:
    ...
    resources: {}
  # BestEffort 확인
status:
  qosClass: BestEffort
```

!!! INFO
    테스트 할때, 혹은 서비스를 배포할때, application이 사용하는 namespace를 구분하면 배포시 발생하는 human error를 피할수 있다.

### 1.2 Burstable Pod 생성하기
* resource requests는 지정되어 있으나(not equal to 0) limit가 없는경우, 혹은 같지가 않을경우 Burstable QoS Pod이 생성된다.

* Pod specification yaml 작성
```bash
# yaml 생성
cat <<EOF > qos-demo-bustable.yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo-bustable
  namespace: qos-example
spec:
  containers:
  - name: qos-demo-ctr
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "700m"
      requests:
        memory: "100Mi"
        cpu: "350m"
EOF
```

* pod 생성 및 QoS 확인
```bash
kubectl apply -f qos-demo-bustable.yaml
pod/qos-demo-bustable created

kubectl get po -n qos-example
NAME                   READY   STATUS    RESTARTS   AGE
qos-demo-bestefforts   1/1     Running   0          89s
qos-demo-bustable      1/1     Running   0          39s

# QoS 확인
kubectl get po -n qos-example qos-demo-bustable -o yaml
apiVersion: v1
kind: Pod
metadata:
  ...
spec:
  containers:
    ...
    resources:
      limits:
        cpu: 700m
        memory: 200Mi
      requests:
        cpu: 350m
        memory: 100Mi
  ...
status:
  # Burstable 확인
  qosClass: Burstable
```

### 1.3 Guaranteed Pod 생성하기
* resource requests/limits를 모두 지정(no equalt to 0)하고, 그것이 동일한 경우 Guaranteed QoS Pod이 생성된다.

* Pod specification yaml 작성
```bash
# yaml 생성
cat <<EOF > qos-demo-guaranteed.yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo-guaranteed
  namespace: qos-example
spec:
  containers:
  - name: qos-demo-ctr
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "700m"
      requests:
        memory: "200Mi"
        cpu: "700m"
EOF
```

* pod 생성 및 QoS 확인
```bash
kubectl apply -f qos-demo-guaranteed.yaml
pod/qos-demo-guaranteed created

kubectl get po -n qos-example
NAME                   READY   STATUS    RESTARTS   AGE
qos-demo-bestefforts   1/1     Running   0          5m28s
qos-demo-bustable      1/1     Running   0          4m38s
qos-demo-guaranteed    1/1     Running   0          11s

# QoS 확인
kubectl get po -n qos-example qos-demo-guaranteed -o yaml
apiVersion: v1
kind: Pod
metadata:
  ...
spec:
  containers:
    ...
    resources:
      limits:
        cpu: 700m
        memory: 200Mi
      requests:
        cpu: 700m
        memory: 200Mi
  ...
status:
  # Guaranteed 확인
  qosClass: Guaranteed
```

### 1.4 cleanup
```bash
kubectl delete -f qos-demo-besteffort.yaml
kubectl delete -f qos-demo-bustable.yaml
kubectl delete -f qos-demo-guaranteed.yaml
```

## 2.Deployment spec에 Requests와 Limits 지정하여 QoS별 Pod을 생성
* deployment spec에 request를 지정하는 부분은 위와 동일함
* deployment spec에 2개의 nginx container를 이용한 request와 limits를 지정하여 qos를 지정한다.

### 2.1 QoS가 지정된 Deployment 생성하기
* deployment specification yaml 작성
```bash
cat <<EOF > qos-demo-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qos-demo-deploy
  namespace: qos-example
spec:
  replicas: 3
  selector:
    matchLabels:
      app: qos-demo
  template:
    metadata:
      labels:
        app: qos-demo
    spec:
      containers:
      - name: qos-demo-ctr-one
        image: nginx
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "200Mi"
            cpu: "700m"
          requests:
            memory: "200Mi"
            cpu: "700m"
      - name: qos-demo-ctr-sidecar
        image: nginx
        # 하나의 pod에 동일 컨테이너를 띄우기 위해 port 변경
        command: ["/bin/sh","-c"]
        args: ["sed -i 's/listen  .*/listen 8000;/g' /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
        ports:
        - containerPort: 8000
        resources:
          limits:
            memory: "300Mi"
            cpu: "500m"
          requests:
            memory: "300Mi"
            cpu: "500m"
EOF
```

* pod 생성 및 QoS 확인
```bash
kubectl apply -f qos-demo-deploy.yaml
deployment.apps/qos-demo-deploy created

kubectl get po -n qos-example
NAME                               READY   STATUS    RESTARTS   AGE
qos-demo-deploy-8476d469b7-7mw5b   2/2     Running   0          61s
qos-demo-deploy-8476d469b7-fjxp8   2/2     Running   0          50s
qos-demo-deploy-8476d469b7-l4nc6   2/2     Running   0          55s

$ kubectl get po -n qos-example qos-demo-deploy-8476d469b7-7mw5b -o yaml
apiVersion: v1
kind: Pod
...
spec:
  containers:
    ...
    name: qos-demo-ctr-one
    ...
    resources:
      limits:
        cpu: 700m
        memory: 200Mi
      requests:
        cpu: 700m
        memory: 200Mi
    ...
    name: qos-demo-ctr-sidecar
    ...
    resources:
      limits:
        cpu: 500m
        memory: 300Mi
      requests:
        cpu: 500m
        memory: 300Mi
status:
  ...
  qosClass: Guaranteed
```

!!! INFO
    하나의 pod에 2개 이상의 container를 실행할때(sidecar pattern) Pod의 QoS를 Guaranteed를 하려면 모든 container의 resources를 Guaranteed의 조건이 만족해야 한다. 예를들면 하나의 Pod의 컨테이너 2개중 하나는 Guranteed 조건을 만족하지만 다른 하나의 container가 Bustable이면 해당 Pod의 QoS는 Bustable이 된다.
    이와 동일하게 2개 이상의 container Pod을 Besteffort로 지정하고 싶다면 모든 container의 resource를 Besteffort 조건에 맞게 지정해야 한다.

### 2.2 Cleanup
```bash
kubectl delete -f qos-demo-deploy.yaml
```
