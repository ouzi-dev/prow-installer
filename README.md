# prow-installer

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
    # If using a registry, specify the version. If the chart is a URL, the version is ignored
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