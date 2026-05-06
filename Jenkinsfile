// ══════════════════════════════════════════════════════════════════════════════
//  Jenkinsfile – Usine Logicielle DevOps TP
//  Exercice 1 : CI + SonarQube Quality Gate
//  Exercice 2 : Docker Build + Trivy Scan + Docker Push
//  Exercice 3 : Terraform IaC + Ansible Deploy + Smoke Test
// ══════════════════════════════════════════════════════════════════════════════

pipeline {

    // ── Agent ─────────────────────────────────────────────────────────────────
    agent {
        // Utilise l'agent Jenkins principal.
        // En production, remplacer par un agent Docker isolé :
        // docker { image 'python:3.12-slim'; args '-u root' }
        label 'built-in'
    }

    // ── Variables globales ────────────────────────────────────────────────────
    environment {
        // Docker Hub
        DOCKER_HUB_USER    = 'gabositos'                        // ← à modifier
        IMAGE_NAME         = 'devops-tp-flask'
        IMAGE_TAG          = "${BUILD_NUMBER}"
        FULL_IMAGE         = "${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

        // SonarQube (nom de la connexion configurée dans Jenkins > Manage > Configure System)
        SONAR_SERVER       = 'SonarQube'

        // Kubernetes / déploiement
        APP_NAMESPACE      = 'devops-tp'
        APP_URL            = 'http://localhost'
        KUBECONFIG_PATH    = '/root/.kube/config'

        // Crédentiels Jenkins (à créer dans Jenkins > Credentials)
        // DOCKER_CREDS   → Username/Password Docker Hub
        // SONAR_TOKEN    → Secret Text token SonarQube
    }

    // ── Options globales ──────────────────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // ── Déclencheurs ──────────────────────────────────────────────────────────
    triggers {
        // Scrute le dépôt Git toutes les 5 minutes (remplacer par webhook en prod)
        pollSCM('H/5 * * * *')
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  STAGES
    // ══════════════════════════════════════════════════════════════════════════
    stages {

        // ──────────────────────────────────────────────────────────────────────
        // EXERCICE 1 – CONTINUOUS INTEGRATION
        // ──────────────────────────────────────────────────────────────────────

        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source...'
                checkout scm
                // Afficher le dernier commit pour traçabilité
                sh 'git log -1 --oneline'
            }
        }

        stage('Install Dependencies') {
            steps {
                echo '📦 Installation des dépendances Python...'
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r app/requirements.txt
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                echo '🧪 Exécution des tests unitaires...'
                sh '''
                    . .venv/bin/activate
                    cd app
                    pytest test_app.py \
                        --tb=short \
                        -v \
                        --junitxml=../reports/junit.xml \
                        --cov=. \
                        --cov-report=xml:../reports/coverage.xml \
                        --cov-report=html:../reports/coverage-html \
                        --cov-fail-under=75
                '''
            }
            post {
                always {
                    // Publier les résultats JUnit dans Jenkins
                    junit 'reports/junit.xml'
                    // Publier le rapport de couverture
                    publishHTML(target: [
                        allowMissing         : false,
                        alwaysLinkToLastBuild: true,
                        keepAll              : true,
                        reportDir            : 'reports/coverage-html',
                        reportFiles          : 'index.html',
                        reportName           : 'Coverage Report'
                    ])
                }
            }
        }

   stage('SonarQube Analysis') {
    steps {
        echo '🔍 Analyse statique du code avec SonarQube...'
        withSonarQubeEnv("${SONAR_SERVER}") {
            sh '''
                /opt/sonar-scanner/bin/sonar-scanner \
                    -Dsonar.projectKey=devops-tp-flask \
                    -Dsonar.sources=app \
                    -Dsonar.tests=app \
                    -Dsonar.test.inclusions=**/test_*.py \
                    -Dsonar.python.coverage.reportPaths=reports/coverage.xml
            '''
        }
    }
}

        stage('Quality Gate') {
            steps {
                echo '🚦 Vérification du Quality Gate SonarQube...'
                // Le pipeline s'arrête en erreur si les métriques ne sont pas respectées
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ──────────────────────────────────────────────────────────────────────
        // EXERCICE 2 – CONTINUOUS DELIVERY : DOCKER + SÉCURITÉ
        // ──────────────────────────────────────────────────────────────────────

        stage('Docker Build') {
            steps {
                echo "🐳 Construction de l'image Docker : ${FULL_IMAGE}"
                sh """
                    docker build \
                        --no-cache \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "build.url=${BUILD_URL}" \
                        --label "git.commit=\$(git rev-parse --short HEAD)" \
                        -t ${FULL_IMAGE} \
                        -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest \
                        .
                """
            }
        }

        stage('Trivy Image Scan') {
            steps {
                echo '🛡️  Scan de sécurité Trivy sur l\'image Docker...'
                sh """
                    # Installer Trivy si absent
                    if ! command -v trivy &> /dev/null; then
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
                            | sh -s -- -b /usr/local/bin
                    fi

                    # Scanner l'image et générer un rapport JSON + tableau
                    trivy image \
                        --exit-code 1 \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output reports/trivy-report.txt \
                        ${FULL_IMAGE}

                    # Rapport JSON pour archivage
                    trivy image \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --format json \
                        --output reports/trivy-report.json \
                        ${FULL_IMAGE}
                """
            }
            post {
                always {
                    // Archiver le rapport Trivy même en cas d'échec
                    archiveArtifacts artifacts: 'reports/trivy-report.*', allowEmptyArchive: true
                }
                failure {
                    echo '❌ Trivy a détecté des vulnérabilités CRITICAL ou HIGH !'
                    echo '   Consultez reports/trivy-report.txt pour les détails.'
                }
            }
        }

        stage('Docker Push') {
            steps {
                echo "📤 Push de l'image vers Docker Hub : ${FULL_IMAGE}"
                withCredentials([usernamePassword(
                    credentialsId: 'DOCKER_CREDS',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                        docker push ${FULL_IMAGE}
                        docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest
                        docker logout
                    """
                }
            }
            post {
                success {
                    echo "✅ Image publiée : https://hub.docker.com/r/${DOCKER_HUB_USER}/${IMAGE_NAME}"
                }
            }
        }

        // ──────────────────────────────────────────────────────────────────────
        // EXERCICE 3 – DÉPLOIEMENT : TERRAFORM + ANSIBLE + SMOKE TEST
        // ──────────────────────────────────────────────────────────────────────

        stage('Terraform Init & Plan') {
            steps {
                echo '🏗️  Initialisation de Terraform...'
                dir('terraform') {
                    sh '''
                        terraform init -input=false

                        terraform plan \
                            -input=false \
                            -var="docker_image=${FULL_IMAGE}" \
                            -var="kubeconfig_path=${KUBECONFIG_PATH}" \
                            -out=tfplan

                        # Afficher un résumé lisible
                        terraform show -no-color tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            // Étape manuelle optionnelle en production
            // input { message 'Appliquer les changements Terraform ?' }
            steps {
                echo '🚀 Application du plan Terraform...'
                dir('terraform') {
                    sh '''
                        terraform apply \
                            -input=false \
                            -auto-approve \
                            tfplan
                    '''
                }
            }
            post {
                failure {
                    echo '❌ Terraform apply a échoué. Rollback possible avec : terraform destroy'
                }
            }
        }

        stage('Ansible Deploy') {
            steps {
                echo "🎭 Déploiement via Ansible : image ${FULL_IMAGE}"
                sh """
                    ansible-playbook ansible/deploy.yml \
                        --extra-vars "docker_image=${FULL_IMAGE}" \
                        --extra-vars "kubeconfig=${KUBECONFIG_PATH}" \
                        --extra-vars "app_url=${APP_URL}" \
                        -v
                """
            }
        }

        stage('Smoke Test') {
            steps {
                echo '💨 Smoke test : vérification de l\'application en ligne...'
                retry(5) {
                    sleep(time: 10, unit: 'SECONDS')
                    sh """
                        # Test endpoint racine
                        HTTP_STATUS=\$(curl -s -o /dev/null -w '%{http_code}' ${APP_URL}/)
                        if [ "\$HTTP_STATUS" != "200" ]; then
                            echo "❌ Smoke test échoué : statut HTTP \$HTTP_STATUS"
                            exit 1
                        fi

                        # Test endpoint /health
                        HEALTH=\$(curl -s ${APP_URL}/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")
                        if [ "\$HEALTH" != "healthy" ]; then
                            echo "❌ Health check échoué"
                            exit 1
                        fi

                        echo "✅ Smoke test réussi – Application accessible sur ${APP_URL}"
                    """
                }
            }
        }

    } // end stages

    // ══════════════════════════════════════════════════════════════════════════
    //  POST-ACTIONS
    // ══════════════════════════════════════════════════════════════════════════
    post {
        always {
            echo '🧹 Nettoyage des ressources locales...'
            sh '''
                # Supprimer les images Docker locales pour libérer l'espace
                docker rmi ${FULL_IMAGE} || true
                docker rmi ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest || true
                docker system prune -f || true
                # Nettoyer l'environnement virtuel Python
                rm -rf .venv
            '''
            // Archiver tous les rapports
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }

        success {
            echo """
            ╔══════════════════════════════════════════════╗
            ║  ✅ PIPELINE RÉUSSI – Build #${BUILD_NUMBER}         ║
            ║  Image  : ${FULL_IMAGE}
            ║  App URL: ${APP_URL}
            ╚══════════════════════════════════════════════╝
            """
        }

        failure {
            echo """
            ╔══════════════════════════════════════════════╗
            ║  ❌ PIPELINE EN ERREUR – Build #${BUILD_NUMBER}       ║
            ║  Consultez les logs pour diagnostiquer.      ║
            ╚══════════════════════════════════════════════╝
            """
            // En production : envoyer une notification email/Slack ici
        }

        unstable {
            echo '⚠️  Pipeline instable (tests partiellement échoués).'
        }
    }

} // end pipeline
