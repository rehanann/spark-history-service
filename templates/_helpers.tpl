{{/* vim: set filetype=mustache: */}}

{{/*
    Create chart name and version as used by the chart label.
*/}}
{{- define "spark.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
    Names standartization
*/}}

{{- define "spark.service-account-name" -}}
b-{{ .Release.Namespace }}-{{- required "A serviceDirectory.component is required" .Values.serviceDirectory.component }}
{{- end -}}

{{- define "spark.name" -}}
{{- required "A serviceDirectory.component is required" .Values.serviceDirectory.component }}-{{- .Release.Name -}}
{{- end -}}

{{- define "hash-suffix" -}}
{{- printf "%s-%s" .Values.serviceDirectory.component .Release.Name | sha256sum | trunc 6 -}}
{{- end -}}

{{- define "spark.pod-name" -}}
{{- /* We are trying to limit pod name to have no more then 63 characters */ -}}
{{- /* For deployment, replicaset would add '-' and 10 characters to deployement name, and pod would add '-' and 5 more characters. */ -}}
{{- $nameLimit := 46 -}}
{{- if .Values.runAsJob -}}
{{- /* For job, pod would only add '-' and 5 characters. */ -}}
{{- $nameLimit := 57 -}}
{{- end }}

{{- $podName := include "spark.name" . -}}
{{- if gt (len $podName) $nameLimit -}}
{{- $suffix := include "hash-suffix" . -}}
{{- trunc (sub $nameLimit (add 1 (len $suffix)) | int) $podName -}}-{{ $suffix }}
{{- else }}
{{- $podName -}}
{{- end }}
{{- end }}

{{- define "spark.service-name" -}}
{{ include "spark.name" . }}
{{- end -}}

{{- define "spark.executor.container.name" -}}
{{- if .Values.sox.enabled}}
{{- printf "app" -}}
{{ else }}
{{- printf "spark-kubernetes-executor" -}}
{{- end -}}
{{- end -}}

{{- define "spark.spark-defaults-conf-cm-name" -}}
{{ include "spark.name" . }}-spark-defaults-conf-cm
{{- end -}}

{{- define "spark.dependenies-yaml-cm-name" -}}
{{ .Release.Name }}-dependencies-yaml
{{- end -}}

{{- define "spark.exec-pod-yaml-cm-name" -}}
{{ include "spark.name" . }}-exec-pod-yaml
{{- end -}}



{{- define "spark.spark-metric-config-cm-name" -}}
{{ include "spark.name" . }}-spark-metric-config
{{- end -}}

{{- define "spark.shared-pvc-name" -}}
{{- if .Values.sharedVolume.useExisting }}
{{- .Values.sharedVolume.existingPvcName -}}
{{- else }}
{{- include "spark.name" . -}}-shared-pvc
{{- end }}
{{- end -}}

{{- define "spark.exec-template-path" -}}
/opt/spark/conf/exec_pod_template.yaml
{{- end -}}


{{/*
    Volumes declarations
*/}}
{{- define "spark.pod-volumes-share-pvc" -}}
- name: shared
  persistentVolumeClaim:
    claimName: {{ include "spark.shared-pvc-name" . }}
{{- end -}}

{{- define "spark.pod-volumes-spark-defaults-conf" -}}
- name: spark-defaults-conf
  configMap:
    name: {{ include "spark.spark-defaults-conf-cm-name" . }}
{{- end -}}

{{- define "spark.pod-volumes-spark-exec-template" -}}
- name: spark-exec-template
  configMap:
    name: {{ include "spark.exec-pod-yaml-cm-name" . }}
{{- end -}}


{{- define "spark.pod-volumes-spark-metric-config" -}}
- name: spark-metric-config
  configMap:
    name: {{ include "spark.spark-metric-config-cm-name" . }}
{{- end -}}

{{- define "spark.merged-configmap-volume" -}}
- name: merged-configmap-volume
  configMap:
    name: {{ .Release.Name }}-merged-configmap
    items:
      - key: spark-defaults.conf
        path: spark-defaults.conf
      - key: exec_pod_template.yaml
        path: exec_pod_template.yaml

{{- end -}}

{{/* Volume Mounts*/}}

{{- define "spark.pod-volumeMounts-spark-defaults-conf" -}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/spark-defaults.conf
  subPath: spark-defaults.conf
{{- end -}}


{{/* Common labels */}}

{{- define "spark.commonLabels" -}}
{{ include "spark.selectorLabels" . }}
bigdata.instance: {{ include "spark.pod-name" . }}
service-directory.service: {{ .Values.serviceDirectory.component | default "bigdata"}}
helm.sh/chart: {{ include "spark.chart" . }}
app.kubernetes.io/name: {{ include "spark.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
application.type: {{ .Values.applicationType }}
{{- end -}}


{{/* Selector labels */}}

{{- define "spark.selectorLabels" }}
app.instance: {{ include "spark.name" . }}
{{- range $key, $val := .Values.appLabels.custom }}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}

{{/*
    Dynamic PVC declarations.
*/}}

{{- define "spark.dynamic-pvc-name" -}}
{{- if (and .Values.aws.enabled .Values.dynamicVolumeProvisioning.enabled) }}
{{- include "spark.name" . -}}-dynamic-pvc
{{- end }}
{{- end -}}

{{- define "spark.pod-volumeMounts-dynamic" -}}
- name: {{ include "spark.dynamic-pvc-name" . }}
  mountPath: {{ .Values.dynamicVolumeProvisioning.mountPath }}
{{- end -}}

{{- define "spark.pod-volumes-dynamic-pvc" -}}
- name: {{ include "spark.dynamic-pvc-name" . }}
  persistentVolumeClaim:
    claimName: {{ include "spark.dynamic-pvc-name" . }}
{{- end -}}

{{/*
    End dynamic pvc.
*/}}


{{/*
    Log4j CM
*/}}

{{- define "spark.log4j-properties-conf" -}}
{{ include "spark.name" . }}-log4j-properties-conf
{{- end -}}

{{- define "spark.pod-volumes-log4j-properties-conf" -}}
- name: log4j-properties-conf
  configMap:
    name: {{ include "spark.log4j-properties-conf" . }}
{{- end -}}


{{- define "spark.pod-volumeMounts-log4j-properties-conf" -}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/log4j.properties
  subPath: log4j.properties-spark
{{- end -}}

{{/*
    End Log4j CM
*/}}

{{/*
    Log4j2 CM
*/}}

{{- define "spark.log4j2-properties-conf" -}}
{{ include "spark.name" . }}-log4j2-properties-conf
{{- end -}}

{{- define "spark.pod-volumes-log4j2-properties-conf" -}}
- name: log4j2-properties-conf
  configMap:
    name: {{ include "spark.log4j2-properties-conf" . }}
{{- end -}}


{{- define "spark.pod-volumeMounts-log4j2-properties-conf" -}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/log4j2.properties
  subPath: log4j2.properties-spark
{{- end -}}

{{/*
    End Log4j2 CM
*/}}


{{- define "test-label-for-driver" -}}
{{- if .Values.test}}
{{- if .Values.test.driverid}}
driver.testid: {{.Values.test.driverid | quote}}
{{- end}}
{{- if .Values.test.cijobid}}
ci.jobid: {{.Values.test.cijobid | quote}}
{{- end}}
{{- else}}
{{printf ""}}
{{- end}}
{{- end}}

{{- define "test-label-for-executor" -}}
{{- if .Values.test}}
{{- if .Values.test.executorid}}
executor.testid: {{.Values.test.executorid | quote}}
{{- end}}
{{- if .Values.test.cijobid}}
ci.jobid: {{.Values.test.cijobid | quote}}
{{- end}}
{{- else}}
{{printf ""}}
{{- end}}
{{- end}}

{{- define "test-label-for-job" -}}
{{- if .Values.test}}
{{- if .Values.test.jobid}}
job.testid: {{.Values.test.jobid | quote}}
{{- end}}
{{- else}}
{{printf ""}}
{{- end}}
{{- end}}