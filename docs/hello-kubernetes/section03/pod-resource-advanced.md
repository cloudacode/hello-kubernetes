---
title: 3.x Deep dive in k8s Pod resources
description:
image:
---

## Deep dive in k8s Pod resources
### 어떻게 kubernetes는 resource의 requests와 limits를 적용하는가?
kubelet이 pod의 일부인 container를 실행할때, kubelet은 container의 cpu/memory의 requests와 limits를 container runtime(e.g. Docker)로 전달한다. Linux 시스템에서는 container에서 사용자가 정의한 수량의 resource를 적용하기 위해 kernel cgroups을 이용하여 구성한다.

* cpu limits : container가 사용가능한 cpu 시간의 하드 리밋을 정의함. 매 스케줄링 인터벌동안(100ms), 리눅스 커널은 지정한 cpu 시간 제한을 넘겼는가를 확인한다. 만약 넘겼다면, 커널은 해당 container의 프로세스의 cpu 연산을 멈추고 다시 실행될때까지 실행을 기다린다(throttled)
* cpu requests: container가 사용가능한 cpu의 가중치. 하나의 호스트에서 여러개의 컨테이너(cgroups)를 실행하는 경우, 더 큰 요청(request)이 있는 워크로드는 작은 요청이 있는 워크로드 보다 더 많은 cpu 시간이 할당됨.

* memory limits: container실행시, cgroup 의 memory limit를 정의함. 만약 container가 limit보다 더 많은 메모리를 할당해서 사용하려고 시도하면, linux kernel의 oom subsystem이 실행되고, 메모리 할당을 시도한 container의 프로세스 중 하나를 중지하여 개입한다.
* memory requests: container를 실행할 때, kubernetes의 노드 스케줄링에 사용되고, 사용 가능한 양(Allocatable resource)를 넘을경우, 스케줄링이 pending된다.

container가 memory reuests 초과하고, 실행되는 노드의 메모리가 부족해지면 container가 속한 Pod가 축출될(evicted) 가능성이 높다.
!!! INFO
    kubernetes.io/memory는 incompressible 속성 - isCompressble: false 을 가짐

그리고 container는 오랜 기간 동안 CPU 제한을 초과하도록 허용되거나 허용되지 않을 수 있습니다.(cpu throttling)
그러나 container runtime(e.g. Docker)은 과도한 CPU 사용으로 인해 Pod 또는 container를 종료하지 않습니다.
!!! INFO
    kubernetes.io/cpu 는 compressible 속성 - isCompressble: true을 가짐

container는 지정한 limits를 초과할 수 없습니다. 요청 및 제한이 적용되는 방식은 리소스가 압축 가능(compressible)한지 또는 압축할 수 없는지(incompressible)에 따라 다르다.


### Compressible Resource Guarantees
resource metadata에 isCompressble: true 속성을 가지는 경우.(e.g. cpu) container는 요청한 cpu 양을 보장받으며 추가 cpu시간을 받을 수도 있고 받지 않을 수도 있다.(실행 중인 다른 작업에 따라 다름) 초과하는 cpu리소스는 요청된 cpu 양에 따라 분배된다.(A : 600m, B: 300m, Node extra 100m -> 2:1 비율로 100milli가 분배됨)
container가 limits를 초과하면 제한(throttled)됩니다. 제한이 지정되지 않은 경우 컨테이너는 사용 가능한 cpu 여유가 있는 경우, 초과 cpu를 사용할 수 있다.

### Incompressible Resource Guarantees
resource metadata에 isCompressble: fales 속성을 가지는 경우.(e.g. memory) container는 요청한 메모리 양을 얻는다. 메모리 요청을 초과하면 상황에 따라 container가 종료될 수 있다. 그러나 container가 요청한 것보다 적은 리소스를 소비하는 경우, 종료하지 않는다.(시스템 작업 또는 데몬에 더 많은 메모리가 필요한 경우 제외). limits보다 많은 메모리를 사용하는 경우 컨테이너가 종료된다.
