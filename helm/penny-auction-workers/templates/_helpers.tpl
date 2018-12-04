{{/* vim: set filetype=mustache: */}}

{{/* Expand the name of the chart. */}}
{{- define "penny-auction-worker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "penny-auction-worker.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- $defaultFullname := printf "%s-%s" .Release.Name $name -}}
{{- default $defaultFullname .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}