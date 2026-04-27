GUIDELLM_TARGET=http://a4b57f432c5af4f019b52817d0c0ddd7-1821355543.us-east-2.elb.amazonaws.com/llm-d-example/gpt-oss-20b/v1
API_KEY=eyJhbGciOiJSUzI1NiIsImtpZCI6ImRzaG9GUno4cUIxelhtaFM4RzVIaUxpVU52WTNhc3BXQlJPRGJWLUNGTGsifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJsbG0tZC1leGFtcGxlIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im15LW1vZGVsLXNlcnZpY2UtZ3B0LW9zcy0yMGItc2EiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZ3B0LW9zcy0yMGItc2EiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJkZGRlODkyYy1lZDMwLTQ0NWEtOTMzYi1kYzgyM2ZjOTkyNzMiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6bGxtLWQtZXhhbXBsZTpncHQtb3NzLTIwYi1zYSJ9.x4I63Va8D0r0x7MQZzosTaa2U5_8i2ZGrsmBoKeRviPcWjTlt4pcgXJq94LGvaakR-4jPvzmdG6yOiNBkZz5xe340RPK3to_1wISVlClIj6KzZFN3WggYM3d73kkUYwesLkYSdEnTi4CtQbuixfN7bijEMP4lBEandsVyq1lP7Lu8_GXCpccmQlKFYPYsiGDKFyTVnmlgPzUXsc-0q7-QuwQr2I-c0916BE-coV7VNdReSEi2VAqe3zbmwlA14RuqJc0Kyenln4fZCQe4GUlRn74cGuMnbUNXeKoDNBRzBYhpa2Z0STycfj-3obt7WVySDP6fIBG5dfuJXgNhOJiOq-pj88HjFOYI3JJiK1RbPARB5aosdFSIPyCtrc-NLd1UqUezebKkUl65luNiD8DVVgUJ-GYWvpaAvMwrb1RckVPNTMNKy-Cei5U71H_p3jRbYIVsJhcWdk73wxkXN4U_trFo3ZCWoqqU23XT_YnSr4PSvFnbPmY5Zakz_srYFGLr5w2AtZEkSwUbZwMAjTsa3vGp42BSlin2IA7_3X85WK9xAWdZ948EkoevSUA9wTR93yKQGgxZqCg9UG7kZd9bLa5u-mh1jPu80-YXrnqDfPXQd0KtYDBQdjsTxETjTcZr90bCQIzK1S5lv-uwcpChlbt2arYFb3PQH8T7E5o8SQ
guidellm benchmark run \
  --target "${GUIDELLM_TARGET}" \
  --model openai/gpt-oss-20b \
  --data "prompt_tokens=4500,prompt_tokens_min=4000,prompt_tokens_max=5000,output_tokens=1000" \
  --rate-type concurrent \
  --rate 1,10,50 \
  --max-seconds 15 \
  --random-seed 1234 
#   --backend-args='{"api_key":"'"${API_KEY}"'"}'



GUIDELLM_TARGET=http://a4b57f432c5af4f019b52817d0c0ddd7-1821355543.us-east-2.elb.amazonaws.com/llm-d-example/gpt-oss-20b
guidellm benchmark run \
  --target "${GUIDELLM_TARGET}" \
  --model openai/gpt-oss-20b \
  --data "prompt_tokens=4500,prompt_tokens_min=4000,prompt_tokens_max=5000,output_tokens=1000" \
  --rate-type concurrent \
  --rate 1,10,50 \
  --max-seconds 15 \
  --random-seed 1234 



GUIDELLM_TARGET=http://a4b57f432c5af4f019b52817d0c0ddd7-1821355543.us-east-2.elb.amazonaws.com/llm-d-example/gpt-oss-20b
guidellm benchmark run \
  --target "${GUIDELLM_TARGET}" \
  --model openai/gpt-oss-20b \
  --data='{"prompt_tokens":500,"output_tokens":500}'  \
  --rate-type concurrent \
  --rate 1,10,50 \
  --max-seconds 15 \
  --random-seed 1234 


GUIDELLM_TARGET=http://a4b57f432c5af4f019b52817d0c0ddd7-1821355543.us-east-2.elb.amazonaws.com/llm-d-example/granite
guidellm benchmark run \
  --target "${GUIDELLM_TARGET}" \
  --model ibm-granite/granite-3.3-2b-instruct \
  --data='{"prompt_tokens":2000,"output_tokens":500}'  \
  --rate-type concurrent \
  --rate 1,10,50 \
  --max-seconds 15 \
  --random-seed 1234 


apiVersion: batch/v1
kind: Job
metadata:
  name: guidellm-benchmark-llm-d
  namespace: gpt-oss-20b-benchmarks
spec:
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: guidellm
          image: ghcr.io/vllm-project/guidellm:latest
          env:
            - name: GUIDELLM_TARGET
              value: "http://openshift-ai-inference-openshift-default.openshift-ingress.svc.cluster.local/llm-d-example/gpt-oss-20b/v1"
            - name: GUIDELLM_PROFILE
              value: "concurrent"
            - name: GUIDELLM_RATE
              value: "32,64"
            - name: GUIDELLM_OUTPUTS
              value: "json,csv"
            - name: GUIDELLM_MAX_SECONDS
              value: "3000"
            - name: GUIDELLM_DATA
              value: '{"prompt_tokens":2000,"output_tokens":500}'
            - name: HF_HOME
              value: "/cache"
            - name: GUIDELLM_REQUEST_TYPE
              value: "text_completions"
          volumeMounts:
            - name: cache
              mountPath: /cache
            - name: results
              mountPath: /results
      volumes:
        - name: cache
          emptyDir: {}
        - name: results
          emptyDir: {}