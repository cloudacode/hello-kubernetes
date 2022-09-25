---
title: 핸즈온 2.6 Configmap & Secret
description: 쿠버네티스 환경에서 설정 파일을 Configmap로 관리 및 중요한 데이터를 Secrets으로 인코딩하여 관리해 보는 실습
image: https://raw.githubusercontent.com/cloudacode/hello-kubernetes/main/docs/assets/kubernetes-school.png
---

# 핸즈온 2.6 Configmap & Secret

**쿠버네티스 환경에서 설정 파일을 Configmap로 관리 및 중요한 데이터를 Secrets으로 인코딩하여 관리해 보는 실습**

로컬 쿠버네티스 환경에서 Nginx 설정 파일을 Configmap으로 관리하고 DB Password를 Secret를 통해 관리해 보는 실습

## 사전 준비 사항

Kind Kubernetes Cluster 구성: [실습 링크](../../section01/handson/setup-local-k8s-kind.md)

Configmap 과 Secret의 이해: [관련 링크](../configmap-secret.md)

## Architecture

Nginx 설정 파일을 Configmap, DB Password를 Secret를 통해 설정 관리

## 1 ConfigMap

### 1.1 ConfigMap 작성하기

아래와 같이 nginx의 설정파일 하나와, key-value 쌍으로 이루는 변수 2개를 포함한 ConfigMap을 만들어본다.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sample-configs
data:
  default_ttl: "30"
  say_hello: "Hi!"

  sample-nginx.conf: |
    server {
      listen            80;
      index             index.html;
      server_name       cloudacode.com;

      location / {
        root  /cloudacode/static/
      }

      location /api {
        proxy_pass  https://api.cloudacode.internal
      }
    }
```

위에서 작성한 파일을 `sample-cm.yaml` 이라고 저장한 뒤, 다음과 같이 ConfigMap 오브젝트를 생성한다.

```text
$ kubectl apply -f sample-cm.yaml
configmap/sample-configs created

$ kubectl get cm
NAME             DATA   AGE
sample-configs   3      27s
```

### 1.2 Pod에 환경변수(Environment Variable)로 ConfigMap의 데이터를 읽어보기

```text
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
spec:
  containers:
  - name: demo
    image: busybox
    command: ["tail", "-f", "/dev/null"]
    env:
    - name: DEFAULT_TTL
      valueFrom:
        configMapKeyRef:
          name: sample-configs
          key: default_ttl
```
위에서 작성한 파일을 `sample-pod.yaml` 이라고 저장한 뒤, 다음과 같이 Pod를 생성한다.

```text
$ kubectl apply -f sample-pod.yaml
pod/sample-pod created

$ kubectl get po --watch
NAME                   READY   STATUS              RESTARTS   AGE
sample-pod   0/1     ContainerCreating   0          4s
sample-pod   1/1     Running             0          6s
```

`sample-pod` 생성이 성공하였다면, 아래와 같이 pod 내부의 환경변수 정보를 조회해본다.
```text
$ k exec sample-pod -- env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=sample-pod
# 아래와 같이 ConfigMap에서 생성한 값이 환경변수로 주입된 것을 확인할 수 있다.
DEFAULT_TTL=30
...
... # ConfigMap에서 설정한 값 이외에도 다양한 환경변수가 출력될 수 있다.
...
```

### 1.3 Pod에 ConfigMap의 데이터를 Volume으로 Mount하여 읽어보기
2.6.1 단계에서 생성한, `sample-configs`의 내용 중, `sample-nginx.conf` 파일을 Volume 형식으로 Pod에 Mount 한 뒤 읽도록 한다.

아래와 같이 Pod를 생성해 본다.
```text
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
      - name: nginx-vhost-config
        mountPath: /etc/nginx/vhosts.d
        readOnly: true
  volumes:
    - name: nginx-vhost-config
      configMap:
        name: sample-configs
        items:
        - key: "sample-nginx.conf"
          path: "sample-nginx.conf"
```

nginx Pod 의 container 내부에 `sample-nginx.conf` 가 어떻게 mount 되었는지 체크해 보도록 한다.
```text
$ k exec nginx -- ls -al /etc/nginx/vhosts.d
total 16
drwxrwxrwx 3 root root 4096 Jul  5 12:56 .
drwxr-xr-x 1 root root 4096 Jul  5 12:56 ..
drwxr-xr-x 2 root root 4096 Jul  5 12:56 ..2022_07_05_12_56_37.2444435617
lrwxrwxrwx 1 root root   32 Jul  5 12:56 ..data -> ..2022_07_05_12_56_37.2444435617
lrwxrwxrwx 1 root root   24 Jul  5 12:56 sample-nginx.conf -> ..data/sample-nginx.conf
```

## 2 Secret

### 2.1 Secret 작성하기
Database에 접근할 때 사용할 ID/PW를 Secret으로 만들어보도록 한다.

ID는 `helloworld`, Password는 `thisispassword`로 가정하여 만드는 과정이다.

우선 plantext 값을 base64 encoding 하는 과정이 필요하다.
```text
$ echo -n "helloworld" | base64 -w0
aGVsbG93b3JsZA==

$ echo -n "thisispassword" | base64 -w0
dGhpc2lzcGFzc3dvcmQ=
```

!!! INFO
   base64 인코딩 시 newline을 포함하지 않고 인코딩 하도록 `base64 -w0` 와 같이 파라미터를 추가한다. (단, MacOS 환경에서는 `base64 -b 0` 와 같이 대체할 수 있다.)
   만약 위와 같이 생성하지 않고 COLS 문자열까지 포함한다면, 추후에 이 값은 환경변수 등에도 똑같이 포함되어 읽혀질 수 있다.

이렇게 얻어낸 값을 Secret 의 data 필드에 `DB_ACCESS_ID` 와 `DB_ACCESS_PW` 로 작성한다.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-account
type: Opaque
data:
  DB_ACCESS_ID: aGVsbG93b3JsZA==
  DB_ACCESS_PW: dGhpc2lzcGFzc3dvcmQ=
```

위에서 작성한 내용을 `sample-secret.yaml` 파일명으로 저장한다. 그리고 kubectl 명령어로 secret을 생성한다.

```text
$ kubectl apply -f sample-secret.yaml
secret/db-account created
```

이렇게 생성한 secret 을 kubectl describe 명령으로 조회하더라도 실제 value 부분은 바로 노출되지 않는다.
```text
$ kubectl describe secret db-account
Name:         db-account
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
DB_ACCESS_ID:  11 bytes
DB_ACCESS_PW:  15 bytes
```

이미 생성된 secret 의 base64 decoded 된 값을 보고 싶다면, 아래와 같이 시도해볼 수 있다.
```text
$ kubectl get secret db-account -o json | jq '.data | map_values(@base64d)'
{
  "DB_ACCESS_ID": "helloworld",
  "DB_ACCESS_PW": "thisispassword"
}
```

### 2.1 Secret 을 Pod의 환경변수로 Mount 하기
2.6.2 에서 생성한 `sample-pod.yaml`를 아래와 같이 수정해본다.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
spec:
  containers:
  - name: demo
    image: busybox
    command: ["tail", "-f", "/dev/null"]
    env:
    - name: DEFAULT_TTL
      valueFrom:
        configMapKeyRef:
          name: sample-configs
          key: default_ttl
    envFrom:
      - secretRef:
          name: db-account
```

생성한 Pod에 `env` 명령을 수행해 환경변수를 조회해본다.
```text
k exec sample-pod -- env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=sample-pod
DB_ACCESS_ID=helloworld
DB_ACCESS_PW=thisispassword
DEFAULT_TTL=30
```

## 3 Clean Up

실습 완료 후 kind cluster 삭제
```
kind delete cluster
```
