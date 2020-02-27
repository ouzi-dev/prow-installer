# prow-installer

## How to deploy all components

- `make deploy` will install all packages in the natural sorting order 

## How to deploy a specific component

- `make $PACKAGE-deploy ` where `PACKAGE` is the package you wish to deploy eg `00-bootstrap` 

## How does this work ?

### Package

A package is effectively a folder called `number-packagename` where number is used for the natural sorting and package name is the package name
Its structure is as follows:
- values.yaml: contains package related tags. 
- `00-manifests` : if this folder exists, then 
  - its contents get templated using the package's values.yaml and the [main one](values.yaml) 
  - they get kubectl applied 
- `01-helm` : if this folder exists, then 
  - the contents of `01-helm/values.yaml` get templated using the package's values.yaml and the [main one](values.yaml)  
  - the chart gets installed using the package's values.yaml `helm.[name|version|chart]` tags. If `helm.version` is not set then `helm.chart` is treated as a being a URL.
- `02-manifests` : if this folder exists, 
  - its contents get templated using the package's values.yaml and the [main one](values.yaml) 
  - they get kubectl applied 