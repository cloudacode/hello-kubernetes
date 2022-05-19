---
title: Event-driven Autoscaling via Keda
description: 엔진엑스 인그래스를 통해 쿠버네티스의 Layer7 레벨의 로드밸런싱을 구현 한다. 
image: https://raw.githubusercontent.com/cloudacode/hello-kubernetes/main/docs/assets/ingress-controller.jpg
---

# Ingress

Ingress는 아래 그림과 같이 클러스터 외부에서 클러스터 내부 서비스로 HTTP와 HTTPS 경로를 노출하고 뒷단의 Service로 라우팅시켜주는 역할을 한다.
![ingress-controller](assets/ingress-controller.jpg)

만약 클라우드 환경에서 쿠버네티스를 쓴다면 클라우드 프로바이더가 managed 형태로 제공해주는 인그래스 컨트롤러를 써도 좋다. 예를 들면 AWS에서 기본 Ingress는 ALB로 매핑이 되며 이것은 AWS가 관리해 주는 리소스이기 때문에 간편하게 사용 할 수 있다. 하지만 다양한 기능들을 커스텀하게 사용하고 싶다거나 self managed 할 수밖에 없는 상황인 경우는 오픈소스 Ingress Controller를 고려해야 한다. 

<div align="right">
<br><a id="channel-add-button" href="http://pf.kakao.com/_nxoaTs">
  <img src="../../assets/channel_add_small.png" alt="kakao channel add button"/>
</a></div>

## Nginx Ingress Controller

[Ingress-Nginx](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx)가 가장 대표적이며 신뢰 할수 있는 솔루션이다. 성능 튜닝이나 Rate limit, JWT vailidation을 Proxy(혹은 LB 레벨)에서 하기를 원한다면 공식적으로 Nginx에서 제공하는 [Nginx-Ingress](https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-helm/)를 써도 좋다.