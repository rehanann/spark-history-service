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
b-{{ .Release.Namespace }}-{{- required "A project.component is required" .Values.project.component }}
{{- end -}}

{{- define "spark.name" -}}
{{- required "A project.component is required" .Values.project.component }}-{{- .Release.Name -}}
{{- end -}}

{{- define "hash-suffix" -}}
{{- printf "%s-%s" .Values.project.component .Release.Name | sha256sum | trunc 6 -}}
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
{{- printf "spark-kubernetes-executor" -}}
{{- end -}}


{{- define "spark.spark-defaults-conf-cm-name" -}}
{{ include "spark.name" . }}-spark-defaults-conf-cm
{{- end -}}

{{- define "spark.exec-pod-yaml-cm-name" -}}
{{ include "spark.name" . }}-exec-pod-yaml
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

{{- define "spark.pod-volumeMounts-spark-exec-template" -}}
- name: merged-configmap-volume
  mountPath: {{ include "spark.exec-template-path" . }}
  subPath: exec_pod_template.yaml
{{- end -}}

{{- define "spark.pod-volumeMounts-core-site-template" -}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/core-site.xml
  subPath: core-site.xml
{{- end -}}

{{- define "spark.pod-volumeMounts-hdfs-site-template" -}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/hdfs-site.xml
  subPath: hdfs-site.xml
{{- end -}}

{{- define "spark.pod-volumeMounts-shared" -}}
- name: shared
  mountPath: {{ .Values.sharedVolume.mountPath }}
{{- end -}}


{{/* Common labels */}}

{{- define "spark.commonLabels" -}}
{{ include "spark.selectorLabels" . }}
bigdata.instance: {{ include "spark.pod-name" . }}
service-directory.service: {{ .Values.project.component | default "gdt"}}
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