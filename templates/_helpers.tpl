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
      - key: core-site.xml
        path: core-site.xml
      - key: hdfs-site.xml
        path: hdfs-site.xml
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

{{- define "spark.pod-volumeMounts-spark-metric-config" -}}
- name: merged-configmap-volume
  mountPath: {{ .Values.metrics.mountPath }}
  subPath: event-metrics.json
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
Hive site xml settings.
*/}}

{{- define "spark.hive-site-xml-cm-name" -}}
{{ include "spark.name" . }}-hive-site-xml-cm
{{- end -}}

{{- define "spark.pod-volumes-hive-site-xml" -}}
{{- if .Values.hive.siteXml.enabled}}
- name: hive-site-xml
  configMap:
    name: {{ include "spark.hive-site-xml-cm-name" . }}
{{- end }}
{{- end -}}

{{- define "spark.pod-volumeMounts-hive-site-xml" -}}
{{- if .Values.hive.siteXml.enabled}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/hive-site.xml
  subPath: hive-site.xml
{{- end}}
{{- end -}}


{{/*
End of Hive site xml settings.
*/}}

{{/*
    Hadoop conf Log4j CM
*/}}

{{- define "spark.hadoopconf-log4j-properties-conf" -}}
{{ include "spark.name" . }}-hadoopconf-log4j-properties-conf
{{- end -}}

{{- define "spark.pod-volumes-hadoopconf-log4j-properties-conf" -}}
- name: hadoopconf-log4j-properties-conf
  configMap:
    name: {{ include "spark.hadoopconf-log4j-properties-conf" . }}
{{- end -}}


{{- define "spark.pod-volumeMounts-hadoopconf-log4j-properties-conf" -}}
- name: merged-configmap-volume
  mountPath: /etc/hadoop/conf/log4j.properties
  subPath: log4j.properties-hadoop
{{- end -}}

{{/*
    End Hadoop conf Log4j CM
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

{{/*
    Python modules requirement.txt declarations
*/}}

{{- define "spark.requirements-txt-driver-cm-name" -}}
{{ include "spark.name" . }}-requirements-txt-driver-cm
{{- end -}}

{{- define "spark.requirements-txt-executor-cm-name" -}}
{{ include "spark.name" . }}-requirements-txt-executor-cm
{{- end -}}

{{- define "spark.pod-volumes-driver-requirements-txt" -}}
{{- if .Values.packages.enabled}}
- name: driver-requirements-txt
  configMap:
    name: {{ include "spark.requirements-txt-driver-cm-name" . }}
{{- end }}
{{- end -}}

{{- define "spark.pod-volumes-executor-requirements-txt" -}}
{{- if .Values.packages.enabled}}
- name: executor-requirements-txt
  configMap:
    name: {{ include "spark.requirements-txt-executor-cm-name" . }}
{{- end }}
{{- end -}}

{{- define "spark.pod-volumeMounts-driver-requirements-txt" -}}
{{- if .Values.packages.enabled }}
- name: merged-configmap-volume
  mountPath: /tmp/requirements.txt
  subPath: requirements_driver.txt
{{- end}}
{{- end -}}

{{- define "spark.pod-volumeMounts-executor-requirements-txt" -}}
{{- if .Values.packages.enabled }}
- name: merged-configmap-volume
  mountPath: /tmp/requirements.txt
  subPath: requirements_executor.txt
{{- end}}
{{- end -}}

{{/*
    End Python modules requirement.txt declarations
*/}}


{{/*
Authx settings starts
*/}}

{{- define "spark.exec-pod-authxagent-yaml-cm-name" -}}
{{ include "spark.name" . }}-exec-pod-authxagent-yaml
{{- end -}}


{{- define "spark.pod-volumes-spark-exec-authxagent-template" -}}
- name: spark-exec-authxagent-template
  configMap:
    name: {{ include "spark.exec-pod-authxagent-yaml-cm-name" . }}
{{- end -}}

{{- define "spark.pod-volumeMounts-spark-exec-authxagent-template" -}}
- name: merged-configmap-volume
  mountPath: /opt/spark/conf/exec_pod_authxagent_template.yaml
  subPath: exec_pod_authxagent_template.yaml
{{- end -}}

{{/*
Authx settings ends
*/}}


{{/*
Readiness settings
*/}}
{{- define "spark.driver-exe-pod-readiness-template" -}}
readinessProbe:
  exec:
    command:
    - /bin/bash
    - -c
    - |
      retries=24
      tries=0
      while [ $tries -le $retries ]; do
          if ! [ -f /tmp/.readiness_healthy.checked ]; then
              sleep 5
          else  
              exit 0
          fi
          tries=$((tries + 1))
      done
  initialDelaySeconds: 5
  periodSeconds: 5
  {{/* failureThreshold: After a probe fails failureThreshold times in a row, 
  Kubernetes considers that the overall check has failed: the container is not ready/healthy/live. 
  failure threshold should match with retries variable, the default tries provdied 3 so after 15 seconds
  if pod didnt able to start then it failed completly. e.g
  https://stackoverflow.com/questions/74714076/how-does-the-failurethreshold-work-in-liveness-readiness-probes-does-it-have#:~:text=Liveness%20probe%20%3A,so%20after%203%20failed%20probes.
   */}}
  failureThreshold: 24
{{- end -}}
{{/*
Readiness settings end
*/}}


{{/*
liveness settings
*/}}
{{- define "spark.driver-exe-pod-liveness-template" -}}
livenessProbe:
  exec:
    command:
    - /bin/bash
    - -c
    - |
      retries=96
      tries=0
      while [ $tries -le $retries ]; do
          if [[ -f /tmp/.liveness_failed.checked ]]; then
              tries=$retries
              exit 1
          elif ! [[ -f /tmp/.liveness_healthy.checked ]]; then
              sleep 5
          else
              exit 0
          fi
          tries=$((tries + 1))
      done
  initialDelaySeconds: 5
  periodSeconds: 5
  {{/* failureThreshold: After a probe fails failureThreshold times in a row, 
  Kubernetes considers that the overall check has failed: the container is not ready/healthy/live. 
  failure threshold should match with retries variable, the default tries provdied 3 so after 15 seconds
  if pod didnt able to start then it failed completly.
   */}}
  failureThreshold: 96
{{- end -}}
{{/*
liveness settings end
*/}}

{{/* fluentbit mounts */}}
{{- define "spark.pod-volumeMounts-spark-driver-exec-fluentbit-template" -}}
- name: varlog
  mountPath: /var/fluentbit 
{{- end -}}
{{/* end fluentbit mounts */}}

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
