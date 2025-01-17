for i in `seq 1 $1`
do
cat <<EOF | kubectl delete -f -
---
apiVersion: v1
kind: Service
metadata:
  name: fulfillment-$i
  namespace: orders
  labels:
    mirror.linkerd.io/exported: "true"
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: fulfillment
EOF
done
