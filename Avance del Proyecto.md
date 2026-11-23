# Plataforma Distribuida de Comercio Electrónico en K3s

Proyecto de Sistemas Distribuidos desplegado sobre un clúster multinodo **K3s** distribuido físicamente entre dos computadoras remotas (**Daniel** y **Alexis**) mediante **Canonical Multipass** y **Tailscale**, integrando microservicios contenerizados, persistencia políglota, mensajería asíncrona con **RabbitMQ** e integración continua con **GitHub Actions** y **GHCR**.

---

## 1. Avance General y Fases Completadas (5 de 9 Fases — ~60%)

* **Fase 0 — Prerrequisitos e imágenes (Completada):** Contenerización de los microservicios (`store-web` en Nginx, `store-api` y `store-worker` en Node.js) siguiendo buenas prácticas *12-factor* mediante variables de entorno, endpoints de salud (`/healthz` y `/readyz`) y etiquetas configuradas para `ghcr.io`.
* **Fase 1 — Infraestructura del clúster K3s de 3 nodos (Completada):** Levantamiento de las 3 máquinas virtuales Ubuntu 24.04 LTS en Multipass sobre Hyper-V (`k3s-node-1` como nodo maestro y `k3s-node-2` como nodo trabajador en la PC de Daniel; `k3s-node-3` como nodo trabajador remoto en la PC de Alexis), interconectadas mediante la red privada VPN Tailscale (WireGuard).
* **Fase 2 — Cargas de trabajo en Kubernetes (Completada):** Despliegue declarativo en el namespace `store` (`Deployments`, `Services`, `ConfigMaps`) y persistencia de datos con **MariaDB** (catálogo relacional), **MongoDB** (reseñas documentales) y **Redis** (caché en memoria).
* **Fase 3 — Colas asíncronas con RabbitMQ (Completada):** Configuración de **RabbitMQ** (`reviews.queue`) para desacoplar la recepción de reseñas en `store-api` y procesarlas en segundo plano mediante `store-worker` hacia MongoDB e invalidación de caché en Redis.
* **Fase 4 — CI/CD con GitHub Actions (Completada):** Pipeline automatizado (`Build and Push Container Images`) operativo en verde (`Success`), compilando y publicando las imágenes Docker en GitHub Container Registry (`ghcr.io`) ante cada `git push`.

---

## 2. Fases Pendientes y Dificultades Técnicas (4 de 9 Fases — ~40%)

| Fase Pendiente | Objetivo Técnico | Dificultades Técnicas y Mitigación |
| :--- | :--- | :--- |
| **Fase 5 — GitOps con FluxCD** | Instalar FluxCD en K3s y conectar `clusters/production` para sincronizar automáticamente los manifiestos `.yaml` desde GitHub. | **Dificultad:** El despliegue completo consume demasiada RAM y rutas mal configuradas pueden fallar o borrar recursos.<br>**Mitigación:** Instalar únicamente `--components="source-controller,kustomize-controller"` y validar la ruta `./k8s` con `prune: false`. |
| **Fase 6 — Observabilidad (Grafana + Loki)** | Desplegar Grafana, Loki y Promtail mediante Helm en el namespace `monitoring` para visualizar logs en vivo. | **Dificultad:** El stack completo de observabilidad con persistencia en disco consume entre 4 GB y 6 GB de RAM, saturando las VMs.<br>**Mitigación:** Usar `grafana/loki-stack` con `--set loki.persistence.enabled=false` en modo ligero (~1 GB de RAM). |
| **Fase 7 — Seguridad (`NetworkPolicy`)** | Aislar MariaDB, MongoDB, Redis y RabbitMQ para que solo `store-api` y `store-worker` puedan conectarse a ellos. | **Dificultad:** Etiquetas (`labels`) mal configuradas bloquean la comunicación interna de la tienda, y Wazuh completo exige demasiada memoria.<br>**Mitigación:** Verificar las etiquetas reales con `kubectl get pods -n store --show-labels` antes de aplicar `NetworkPolicy`. |
| **Fase 8 — Validación y Runbooks** | Ejecutar pruebas en vivo de caída/recuperación de pods y del nodo remoto (`k3s-node-3`), y documentar `docs/runbooks/operacion-cluster.md`. | **Dificultad:** Apagar las máquinas virtuales en orden incorrecto puede corromper las conexiones de las bases de datos.<br>**Mitigación:** Seguir estrictamente el apagado inverso (primero `k3s-node-3` de Alexis, luego `k3s-node-2` y al final el maestro `k3s-node-1`). |

---

## 3. Pila Tecnológica y Herramientas del Proyecto

| Categoría | Herramienta | Rol en el proyecto |
| :--- | :--- | :--- |
| **Control de versiones y Colaboración** | Git y GitHub (con **Fork** y Pull Requests) | Clonación independiente del repositorio base mediante **Fork** (`DanielGonzalez17/distributedsystems`), control de código fuente, manifiestos YAML y colaboración segura entre Daniel y Alexis. |
| **Virtualización e infraestructura** | Canonical Multipass | Creación y administración de las máquinas virtuales Ubuntu 24.04 LTS (`k3s-node-1`, `k3s-node-2` y `k3s-node-3`) sobre Hyper-V en Windows. |
| **Red privada (VPN Mesh)** | Tailscale | Interconexión segura mediante red privada virtual (WireGuard) entre la computadora de Daniel y la de Alexis a través de internet. |
| **Orquestación de contenedores** | K3s (Kubernetes ligero) y `kubectl` | Despliegue, escalamiento, balanceo de carga, autorrecuperación y gestión de pods/servicios del namespace `store` en los 3 nodos. |
| **Contenedores** | Docker / `containerd` | Empaquetado y ejecución aislada de los microservicios (`store-api`, `store-web`, `store-worker`) y componentes de datos. |
| **Bases de datos** | MariaDB y MongoDB | Almacenamiento relacional (SQL) para el catálogo de productos en MariaDB y almacenamiento documental (NoSQL) para reseñas en MongoDB. |
| **Caché en memoria** | Redis | Almacenamiento clave-valor en memoria para acelerar las consultas de productos y reducir la carga en MariaDB. |
| **Mensajería asíncrona** | RabbitMQ | Cola de mensajes (`reviews.queue`) que desacopla la recepción de reseñas en la API de su procesamiento en segundo plano. |
| **Microservicios y Frontend** | Node.js / Nginx / Web UI | Backend (`store-api`), consumidor de cola (`store-worker`) e interfaz web (`store-web` con proxy inverso Nginx). |
| **CI/CD y Registro (Fase 4)** | GitHub Actions y GHCR (`ghcr.io`) | Compilación automatizada de imágenes Docker ante cada `git push` y almacenamiento en el registro de contenedores. |
| **GitOps (Fase 5 — Pendiente)** | FluxCD | Sincronización continua y automatizada entre los manifiestos YAML del repositorio de GitHub y el estado del clúster K3s. |
| **Observabilidad y Seguridad (Fases 6–7 — Pendientes)** | Helm, Grafana + Loki y `NetworkPolicy` | Visualización centralizada de logs en vivo de los microservicios y aislamiento de red para proteger las bases de datos y RabbitMQ. |
| **Terminal y automatización** | Windows PowerShell | Administración de servicios locales de Multipass, túneles `port-forward` y ejecución de comandos de control del clúster. |

---

## 4. Papel de GitHub y Uso de Fork en la Arquitectura

En este sistema distribuido, **GitHub** no ejecuta la tienda en vivo (la cual corre en el clúster local de K3s de Daniel y Alexis), sino que cumple **cuatro funciones esenciales**:

1. **Bifurcación del Proyecto Base mediante Fork:** Se creó un **Fork** del repositorio original del proyecto hacia la cuenta del equipo (`DanielGonzalez17/distributedsystems`). Esto permite contar con una copia propia e independiente en la nube donde podemos modificar código, adaptar manifiestos de Kubernetes y configurar flujos de automatización sin alterar el repositorio fuente del docente, manteniendo trazabilidad de cambios y facilitando contribuciones mediante *Pull Requests*.
2. **Repositorio Central Colaborativo:** Centraliza el código fuente (`./web`, `./application`, `./worker`), los manifiestos `.yaml` de Kubernetes y los manuales operativos para que ambos integrantes trabajen sincronizados a distancia (`git pull` / `git push`).
3. **Fábrica Automatizada de Contenedores (GitHub Actions):** Cada vez que se realiza un `git push` hacia la rama `main` del Fork, el flujo `Build and Push Container Images` compila en la nube las tres imágenes Docker sin consumir recursos de las laptops locales.
4. **Almacén de Imágenes en la Nube (GitHub Container Registry — `ghcr.io`):** Publica y versiona las imágenes listas (`store-web`, `store-api` y `store-worker`) vinculadas a nuestro repositorio para que los tres nodos del clúster K3s descarguen y ejecuten exactamente la misma versión del software.