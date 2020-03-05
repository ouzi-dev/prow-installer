# prow-installer <!-- omit in toc -->

- [Overview](#overview)
- [Why](#why)
- [Features](#features)
- [Packages](#packages)
- [How to deploy all components](#how-to-deploy-all-components)
- [How to deploy a specific component](#how-to-deploy-a-specific-component)
- [How does this work ?](#how-does-this-work-)
  - [What is a Package](#what-is-a-package)
  - [How is the Package deployed](#how-is-the-package-deployed)

## Overview

Installs Prow and all components needed to support in on a GKE Kubernetes Cluster.

## Why 

In order to get Prow up and running on a vanilla GKE Kubernetes cluster one has to install various components. This installer installs everything needed to get a self sustaining Prow installation in a vanilla GKE cluster.

## Features

* PodDisruptionBudgets for all GKE system components such that the AutoScaler works nicely.
* Drain GKE Preemptible Nodes before GKE takes them away to minimize disruption
  * This means that all Preemptible nodes get recycled every 12-16 hours. 
* Handle Node Termination signals from GKE
  * When GKE sends a SIGTERM to a node, the controller makes sure the node starts draining gracefully to minimize disruption
* Fetches CredStash Secrets and injects them in the prow and build namespaces
* Create/Renew TLS Certificates via cert-manager
* authN's the prow dashboard and other ingress' using GitHub OAuth
* Create/Update DNS Records using external-dns
* Provide Ingress using the nginx-ingress-controller
* Manages Prow and all of its components

## Packages

The installer will deploy the following packages:

| Package | Notes  | Docs   |
| ------- | ------ | ------ | 
| [bootstrap](packages/00-bootstrap/) | contains cluster role bindings for the admin group, storage classes and pod disruption budgets for the smooth operation of the GKE AutoScaler | [link]() |
| [gke preemptible killer](packages/11-gkepreemptiblekiller) | kills the [GKE preemptible](https://cloud.google.com/kubernetes-engine/docs/how-to/preemptible-vms) nodes before Google reclaims them. This means that instances get recycled every 12 hours or thereabouts | [link](https://github.com/estafette/estafette-gke-preemptible-killer) |
| [gke node termination handler](packages/12-gkenodeterminationhandler) | watches for a signal from GKE that the node is being killed and gracefully terminates pods on the nodes in question | [link](https://github.com/GoogleCloudPlatform/k8s-node-termination-handler) |
| [credstashoperator](packages/10-credstashoperator) | allows us to have CredstashSecrets and use them for builds | [link](https://github.com/ouzi-dev/credstash-operator) |
| [cert-manager](packages/04-certmanager) | creates and manages TLS certificates for all ingress and external services | [link](https://github.com/jetstack/cert-manager) |
| [oauthproxy](packages/05-oauthproxy) | provides authN to ingress using GitHub OAuth app | [link](https://github.com/pusher/oauth2_proxy) |
| [externaldns](packages/06-externaldns) | manages DNS records from ingress | [link](https://github.com/kubernetes-sigs/external-dns) |
| [nginxingress](packages/07-nginxingress) | manages an nginx cluster for all ingress' in the cluster | [link](https://github.com/kubernetes/ingress-nginx) |
| [prow](packages/08-prow) | creates all prow components in the cluster | [link](https://github.com/ouzi-dev/prow-helm-chart) |
| [buildsecrets](packages/09-buildsecrets) | creates CredstashSecrets for builds | [link](https://github.com/ouzi-dev/credstash-operator)

## How to deploy all components

- `make deploy` will install all packages in the natural sorting order 

## How to deploy a specific component

- `make $PACKAGE-deploy ` where `PACKAGE` is the package you wish to deploy eg `00-bootstrap` 

## How does this work ?

### What is a Package

A package is effectively a folder called `number-packagename` where number is used for the natural sorting and package name is the package name.

- values.yaml: contains package related tags, eg:
  ```
  nginxingress:
  namespace: nginx-ingress
  helm:
    # The name of the Release
    name: peach
    # The chart's name - can also be a URL
    chart: stable/nginx-ingress
    # If using a registry, specify the version. If the chart is a URL, set the version to null
    version: 1.24.4
  ```
- `00-manifests` : 
  - Contains yaml manifests that get templated using the package's values.yaml and the [main one](values.yaml) 
- `01-helm` : 
  - Contains helm chart's values.yaml. Supports templating
- `02-manifests` : 
  - Contains yaml manifests that get templated using the package's values.yaml and the [main one](values.yaml) 


### How is the Package deployed

- values.yaml: contains package related tags which are used in the steps below

- `00-manifests` : Runs always first. If it does not exist, its skipped
  - Contents get templated using the package's values.yaml and the [main one](values.yaml) 
  - `kubectl apply` gets executed

- `01-helm` : Runs always after `00-manifests`. If it does not exist, its skipped
  - Contents of `01-helm/values.yaml` get templated using the package's values.yaml and the [main one](values.yaml)  
  - Chart gets installed/upgraded using the package's values.yaml `helm.[name|version|chart]` tags
    - If `helm.version` is not set then `helm.chart` is treated as a being a URL

- `02-manifests` : Runs always after `01-helm`. If it does not exist, its skipped 
  - Contents get templated using the package's values.yaml and the [main one](values.yaml) 
  - `kubectl apply` gets executed