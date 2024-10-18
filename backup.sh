#!/bin/bash

# Cargar el perfil de usuario donde se configura gcloud y kubectl
source /home/webapp/.bashrc

# Especificar el PATH donde se encuentran gcloud, kubectl, y gsutil
export PATH=$PATH:/usr/bin:/usr/local/bin:/home/webapp/google-cloud-sdk/bin

# Variables
NAMESPACE="esb"
CLUSTER_NAME="grails-apps"
CLUSTER_ZONE="us-east1-b"
PROJECT_ID="wf-panama-ipaas-devel"
PVC_PATH="/home"
BUCKET_NAME="aig-sftp-bucket"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="backup-$TIMESTAMP.tar.gz"
LOCAL_PATH="/tmp/$BACKUP_FILE"
GCS_PATH="gs://$BUCKET_NAME/"

# Autenticación con Google Cloud y el cluster de Kubernetes
gcloud auth activate-service-account --key-file=gcp-key.json
gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID

# Obtener el nombre del Pod
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=reports-sftp -o jsonpath="{.items[0].metadata.name}")

# Crear el archivo tar.gz del contenido de /home dentro del Pod
kubectl exec -n $NAMESPACE $POD_NAME -- tar -czf /tmp/$BACKUP_FILE -C $PVC_PATH .

# Copiar el archivo tar.gz al sistema local
kubectl cp $NAMESPACE/$POD_NAME:/tmp/$BACKUP_FILE $LOCAL_PATH

# Subir el archivo tar.gz al bucket de Google Cloud Storage
gsutil cp $LOCAL_PATH $GCS_PATH

# Eliminar el archivo temporal local
rm $LOCAL_PATH

# Eliminar archivos más antiguos de 7 días en el bucket
gsutil ls -l $GCS_PATH | grep -E "backup-[0-9]{14}\.tar\.gz" | while read -r line; do
    FILE_DATE=$(echo $line | awk -F'backup-' '{print $2}' | awk -F'.tar.gz' '{print $1}')
    FORMATTED_DATE=$(echo $FILE_DATE | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3 \4:\5:\6/')
    FILE_TIMESTAMP=$(date -d $FILE_DATE +%s)
    SEVEN_DAYS_AGO=$(date -d "7 days ago" +%s)
    if [ -n "$FILE_TIMESTAMP" ] && [ "$FILE_TIMESTAMP" -lt "$SEVEN_DAYS_AGO" ]; then
        gsutil rm "$GCS_PATH/backup-$FILE_DATE.tar.gz"
    fi
done

