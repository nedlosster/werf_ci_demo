{{- define "app2.name" -}}app2-python-angular{{- end -}}

{{- define "app2.labels" -}}
app.kubernetes.io/name: {{ include "app2.name" . }}
app.kubernetes.io/part-of: werf-ci-demo
app.kubernetes.io/managed-by: werf
{{- end -}}
