{{- define "app1.name" -}}app1-java-react{{- end -}}

{{- define "app1.labels" -}}
app.kubernetes.io/name: {{ include "app1.name" . }}
app.kubernetes.io/part-of: werf-ci-demo
app.kubernetes.io/managed-by: werf
{{- end -}}
