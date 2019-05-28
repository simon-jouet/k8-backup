# Backup image for kubernetes

Included in this image:
 * kubectl
 * rclone
 * gnupg

## Example - GitLab

 * Creates a backup of GitLab using the task-runner to the local minio
 * Copy the backup to a cloud storage using rclone
 * Cleanup old backups

Note: to be able to call kubectl from within the pod you need to pass a valid serviceAccountName

### Creating the secret

```shell
$ kubectl create secret generic backups-rclone --from-file=rclone.conf
```

### Kubernetes resources

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitlab-backup
data:
  entrypoint.sh: |-
    #!/bin/sh
    # Create the gitlab backup
    POD=$(kubectl get pods -lrelease=gitlab -lapp=task-runner --field-selector=status.phase=Running -oname|head -n 1 |cut -d / -f 2)
    if [ -z "$POD" ]; then
      exit 1
    fi
    kubectl exec -t $POD -- backup-utility --skip registry --skip artifacts --skip lfs --skip uploads --skip packages
    if [ "$?" -ne "0" ]; then
      exit 1
    fi

    # Push the backup to swift
    rclone copy minio:gitlab-backups swift:backups/gitlab

    # Remove backups that are over 7d old
    rclone delete --min-age=7d swift:backups/gitlab
---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: gitlab-backup
spec:
  schedule: "0 4 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      backoffLimit: 0
      template:
        metadata:
          labels:
            app: gitlab-backup
        spec:
          containers:
            - name: gitlab-backup
              image: simonj/backup
              command: ["/bin/entrypoint.sh"]
              volumeMounts:
                - name: rclone
                  mountPath: "/root/.config/rclone"
                  readOnly: true
                - name: entrypoint
                  mountPath: /bin/entrypoint.sh
                  readOnly: true
                  subPath: entrypoint.sh
          volumes:
            - name: rclone
              secret:
                secretName: backups-rclone
            - name: entrypoint
              configMap:
                defaultMode: 0700
                name: gitlab-backup  
          restartPolicy: Never
          serviceAccountName: backups
```