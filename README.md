# Usine Logicielle DevOps – TP Complet

Pipeline CI/CD de bout en bout pour une application **Python Flask**, incluant qualité de code,
conteneurisation sécurisée, Infrastructure as Code et observabilité.

---

## Structure du projet

```
devops-tp/
├── app/
│   ├── app.py              # Application Flask + métriques Prometheus
│   ├── test_app.py         # Tests unitaires pytest
│   └── requirements.txt
├── terraform/
│   ├── provider.tf         # Providers Kubernetes + Helm
│   ├── variables.tf
│   ├── main.tf             # Namespaces, Helm Prometheus stack, ServiceMonitor
│   └── outputs.tf
├── ansible/
│   └── deploy.yml          # Playbook de déploiement K8s
├── k8s/
│   └── deployment.yaml     # Deployment + Service + Ingress
├── monitoring/
│   ├── alertmanager-rules.yaml   # PrometheusRule + config AlertManager
│   └── grafana-dashboard.json    # Dashboard JSON à importer
├── Dockerfile              # Multi-stage build
├── sonar-project.properties
├── Jenkinsfile             # Pipeline complet (Ex 1 → 3)
└── README.md
```

---

## Prérequis

| Outil | Version minimale | Installation |
|-------|-----------------|--------------|
| Jenkins | 2.440 | https://www.jenkins.io/download/ |
| Docker | 24.x | https://docs.docker.com/engine/install/ |
| kubectl | 1.29 | https://kubernetes.io/docs/tasks/tools/ |
| minikube | 1.33 | https://minikube.sigs.k8s.io/docs/start/ |
| Terraform | 1.7 | https://developer.hashicorp.com/terraform/install |
| Ansible | 9.x | `pip install ansible kubernetes` |
| Trivy | 0.50 | https://aquasecurity.github.io/trivy/latest/getting-started/installation/ |
| sonar-scanner | 5.x | https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/ |

---

## Mise en place pas-à-pas

### 1. Démarrer Minikube

```bash
minikube start --driver=docker --cpus=4 --memory=6g
minikube addons enable ingress
minikube addons enable metrics-server

# Ajouter l'entrée DNS locale
echo "$(minikube ip) devops-tp.local" | sudo tee -a /etc/hosts
```

### 2. Démarrer SonarQube (Docker)

```bash
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  sonarqube:community

# Attendre ~60s, puis ouvrir http://localhost:9000
# Login : admin / admin (changer au premier login)
# Créer un projet "devops-tp-flask" et générer un token
```

### 3. Configurer Jenkins

#### Plugins nécessaires
Installer depuis *Manage Jenkins > Plugins* :
- `Pipeline`
- `Git`
- `SonarQube Scanner`
- `Docker Pipeline`
- `HTML Publisher`
- `JUnit`

#### Credentials à créer (Manage Jenkins > Credentials)

| ID | Type | Valeur |
|----|------|--------|
| `DOCKER_CREDS` | Username/Password | Login Docker Hub |
| `SONAR_TOKEN` | Secret Text | Token SonarQube |

#### Configurer SonarQube dans Jenkins
*Manage Jenkins > Configure System > SonarQube Servers* :
- Name : `SonarQube`
- URL : `http://localhost:9000`
- Token : sélectionner `SONAR_TOKEN`

#### Créer le pipeline
1. *New Item > Pipeline*
2. *Definition* : Pipeline script from SCM
3. SCM : Git, URL de votre dépôt
4. Script Path : `Jenkinsfile`

### 4. Initialiser Terraform

```bash
cd terraform
terraform init
terraform plan -var="docker_image=monuser/devops-tp-flask:1"
```

### 5. Lancer le pipeline Jenkins

Déclencher manuellement ou pousser un commit.  
Le pipeline exécute automatiquement tous les stages.

---

## Exercice 4 – Observabilité

Après un premier déploiement réussi :

### Accéder à Grafana

```bash
# Récupérer l'IP de Grafana
minikube service kube-prometheus-stack-grafana -n monitoring --url

# Ou via port-forward
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Ouvrir http://localhost:3000  |  admin / DevOpsTP2024!
```

### Importer le dashboard

1. Grafana > *Dashboards > Import*
2. Uploader `monitoring/grafana-dashboard.json`
3. Sélectionner la datasource Prometheus

### Appliquer les règles AlertManager

```bash
kubectl apply -f monitoring/alertmanager-rules.yaml -n monitoring

# Vérifier que la règle est chargée
kubectl get prometheusrule -n monitoring
```

### Tester l'alerte "service down"

```bash
# Scaler à 0 replicas pour simuler une panne
kubectl scale deployment devops-tp-flask --replicas=0 -n devops-tp

# Attendre 2 minutes → vérifier dans Alertmanager
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
# Ouvrir http://localhost:9093
```

---

## Livrables attendus

- [ ] **Dépôt Git** avec tout le code (ce projet)
- [ ] **Jenkinsfile** unique (`Jenkinsfile` à la racine)
- [ ] **Rapport** avec captures :
  - Dashboard SonarQube (Quality Gate vert)
  - Image visible sur Docker Hub avec tag `${BUILD_NUMBER}`
  - `kubectl get pods -n devops-tp` (pods Running)
  - Dashboard Grafana actif avec métriques
  - Alerte AlertManager visible

---

## Variables à personnaliser

Avant de lancer le pipeline, modifier dans `Jenkinsfile` :

```groovy
DOCKER_HUB_USER = 'monuser'   // ← votre login Docker Hub
```

Et dans `terraform/variables.tf` :

```hcl
default = "minikube"           // ← votre contexte kubectl (kind-kind, etc.)
```
