---
title: 핸즈온 3.2 Persistent Volume & Claim
description: Persistent Volume 구성 및 Pod에 생성한 볼륨을 마운트 해보는 실습
image: https://raw.githubusercontent.com/cloudacode/hello-kubernetes/main/docs/assets/kubernetes-school.png
---

# 핸즈온 3.2 Persistent Volume & Claim

**Persistent Volume 구성 및 Pod에 생성한 볼륨을 마운트 해보는 실습**

로컬 쿠버네티스 환경에서 EmptyDir과 Persistent Volume을 각각 구성하고 Pod에 해당 볼륨을 마운트 해보는 실습

## 사전 준비 사항

Kind Kubernetes Cluster 구성: [실습 링크](../../section01/handson/setup-local-k8s-kind.md)

Kubernetes Volume 이해: [관련 링크](../storage-persistent-volume.md)

## Architecture

Ephemeral과 Persistent Volume을 각각 구성하고 Pod에 해당 볼륨을 마운트

![]()

!!! INFO
    Kind 클러스터 환경에서는 기본으로 [local-path-provisioner](https://github.com/rancher/local-path-provisioner)가 Dynamic Provisioner로 구성이 되어 있어 별도의 CSI Provisioner를 구성할 필요가 없다. 해당 리소스는 `local-path-storage` 네임스페이스에 구성 되어 있다.

## 1 Ephemeral Volume

EmptyDir

### 1.1 EmptyDir 설정

파드 생성시 emptydir을 볼륨으로 마운트 하도록 설정

[busybox-emptydir.yaml](../snippets/busybox-emptydir.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-sleep-1000
spec:
  containers:
  - name: busybox
    image: busybox:1.28
    args:
    - sleep
    - "1000"
    volumeMounts:
    - mountPath: /data
      name: empty-data
  volumes:
  - name: empty-data
    emptyDir: {}
```

### 1.2 Volume 확인

```bash
# Pod의 Data 디렉토리에 임시 파일 생성
kubectl exec -it busybox-sleep-1000 -- /bin/sh -c "echo abcd > /data/test.txt"
# Pod의 UID 확인
kubectl get pods/busybox-sleep-1000 -o jsonpath='{.metadata.uid}'
# Pod가 기동중인 Node 확인
kubectl get pods/busybox-sleep-1000 -o jsonpath='{.spec.nodeName}'
```

Pod가 기동중인 Node에서 실제 emptyDir이 만들어져 컨테이너에서 임의로 생성한 파일이 보이는지 확인
```bash
root@kind-worker3:/# ls -al /var/lib/kubelet/pods/fd0b963c-3ef0-4ebb-be52-258f935f161b/volumes/kubernetes.io~empty-dir/empty-data/
total 12
drwxrwxrwx 2 root root 4096 Aug  3 20:31 .
drwxr-xr-x 3 root root 4096 Aug  3 20:29 ..
-rw-r--r-- 1 root root    5 Aug  3 20:31 test.txt
root@kind-worker3:/# cat /var/lib/kubelet/pods/fd0b963c-3ef0-4ebb-be52-258f935f161b/volumes/kubernetes.io~empty-dir/empty-data/test.txt
abcd
```

Pod 삭제, 재생성시 볼륨이 초기화 되어 있는지 확인

```bash

```

## 2 Persistent Volume

Kind 클러스터에서는 Dynamic Provisoner(local-path-provisioner)가 기본으로 구성이 되어 있다

### 2.1 Persistent Volume Claim 구성

[busybox-data-pvc.yaml](../snippets/busybox-data-pvc.yaml)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pv-claim
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

!!! INFO
    StorageClass에 VOLUMEBINDINGMODE가 WaitForFirstConsumer라면 PV가 실제로 생성되는 시점은 PVC가 생성된 시점이 아닌 실제 파드 리소스가 PVC를 마운트 하는 시점에 생성이 된다

```bash
kubectl get sc
NAME                 PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path          Delete          WaitForFirstConsumer   false                  25h

kubectl get pv,pvc
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS    REASON   AGE

NAME                                   STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
persistentvolumeclaim/data-pv-claim    Pending                                                                        standard        24s
```

### 2.2 데모앱 배포

위에서 요청한 PVC를 BusyBox 파드에 마운트

[busybox-pv.yaml](../snippets/busybox-pv.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-sleep-1000
spec:
  containers:
  - name: busybox
    image: busybox:1.28
    args:
    - sleep
    - "1000"
    volumeMounts:
    - mountPath: /data
      name: data-volume
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: data-pv-claim
```

Pod 배포시 Dynamic하게 PV까지 생성되어 PVC에 Bound 된 것을 확인

```bash
kubectl get pod,pvc,pv
NAME                          READY   STATUS    RESTARTS   AGE
pod/busybox-sleep-1000        1/1     Running   0          28s

NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
persistentvolumeclaim/data-pv-claim    Bound    pvc-c2e346e2-c9df-410a-835d-9b1a06eda595   1Gi        RWO            standard        2m27s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS    REASON   AGE
persistentvolume/pvc-c2e346e2-c9df-410a-835d-9b1a06eda595   1Gi        RWO            Delete           Bound    demo/data-pv-claim    standard                 24s
```

Pod의 Data 디렉토리에 임시 파일 생성
```bash
kubectl exec -it busybox-sleep-1000 -- /bin/sh -c "echo abcd > /data/test.txt"
```

## 3. 접근 확인

파드가 생성된 워커 노드에 접근하여 local-path-provisioner 볼륨에 PV가 생성되어 파일이 접근 되는지 확인

```bash
kubectl get pods/busybox-sleep-1000 -o jsonpath='{.spec.nodeName}'
```

```bash
root@kind-worker:/# ls -al /var/local-path-provisioner/pvc-c2e346e2-c9df-410a-835d-9b1a06eda595_demo_data-pv-claim/
total 12
drwxrwxrwx 2 root root 4096 Aug  3 23:03 .
drwxr-xr-x 3 root root 4096 Aug  3 22:57 ..
-rw-r--r-- 1 root root    6 Aug  3 23:03 test.txt
```

Pod 삭제 및 동일한 PVC를 마운트 하며 재생성

```bash
kubectl delete pod/busybox-sleep-1000
kubectl apply -f busybox-pv.yaml
```

기존에 작성한 임시 파일이 영구적으로 남아 있는지 확인:
**Pod는 삭제 되었더라도 Volume은 삭제 하지 않았기 때문에 데이터를 영구적으로 관리 가능**

```bash
kubectl exec -it busybox-sleep-1000 -- /bin/sh
/ # cd /data/
/data # ls
test.txt
/data # ls -al
total 12
drwxrwxrwx    2 root     root          4096 Aug  3 22:07 .
drwxr-xr-x    1 root     root          4096 Aug  3 22:38 ..
-rw-r--r--    1 root     root             6 Aug  3 22:07 test.txt
```

## 4 Clean Up
실습 완료 후 kind cluster 삭제
```
kind delete cluster
```
