> **This is a temporary repository for an SRE interview.** It is deleted within 24 hours
> of the session.

# Shop

Shop is an online store at <https://shop.interview.tubi.io>.

```
browser -> Route53 -> ALB -> web -> api -> payments
                                    |  -> recs
                                    +-> PostgreSQL (RDS, shop-db)
worker -> PostgreSQL, receipts (file server)
```

Everything runs in the EKS cluster `sre-interview-lab` (namespace `shop`), region
`us-east-2`, except the database, which is RDS.

## Repo layout

| Path | What it is | How it ships |
|---|---|---|
| `k8s/shop/` | Kubernetes manifests (kustomize) | `kubectl apply -k k8s/shop` |
| `terraform/shop/` | RDS `shop-db`, its security group, its parameter group, and its subnet group | `terraform apply` |
| `.github/workflows/deploy.yml` | Deploys `main`: Terraform first, then the manifests | Every push to `main` |

**Deploys:** fork this repo, push a branch to your fork, and open a pull request.
The interviewer reviews and merges it, and the `deploy` workflow applies `main`
within about two minutes. A new commit on the pull request needs a new review. Pull
requests run no workflow. At the end of the session, delete your fork.

To preview a Terraform change with your own credentials:

```
cd terraform/shop
terraform init
terraform plan
```

## Services

Every service is the same image (`shop`), started in a different mode, and reads
its settings from environment variables. The manifests set the ones that differ
from the defaults; the database address, credentials, and pool size come from
the Secret `shop-db`. `kubectl -n shop exec deploy/api -- /shop settings` prints
every setting with its default and what it does. Every HTTP service listens on
port 8080 and serves:

- `GET /healthz`: 200 while the process runs.
- `GET /healthz/ready`: 200 when the service is ready for traffic.
- `GET /metrics`: Prometheus metrics.

Logs are JSON lines with `level`, `msg`, and, on failures, `error`.

| Service | Kind | What it does | Endpoints |
|---|---|---|---|
| `web` | Deployment | The storefront; the ALB sends every request here | `GET /`, `GET /product/{id}`, `POST /cart`, `POST /checkout`, `GET /receipt/{order}` |
| `api` | Deployment + HPA | Products, carts, and checkouts | `GET /products/{id}`, `GET /products/{id}/recommendations`, `POST /cart`, `POST /checkout` |
| `payments` | Deployment | Payment provider | `POST /charge` |
| `recs` | Deployment | Product recommendations | `GET /recommendations?product={id}` |
| `worker` | Deployment | Makes a receipt for each new order and uploads it to `receipts` | — |
| `receipts` | StatefulSet (nginx) | Receipt file server: `PUT` stores a file, `GET` returns it | `PUT/GET /receipts/{order}.txt`, `GET /healthz` |
| `cart-cleanup` | CronJob, every 5 min | Deletes abandoned carts | — |

## Metrics

| Family | Metrics | From |
|---|---|---|
| HTTP server | `http_requests_total`, `http_request_duration_seconds`, `http_requests_in_flight` (labels `route`, `code`) | web, api, payments, recs |
| HTTP client | `http_client_requests_total`, `http_client_request_duration_seconds` (labels `target`, `code`) | web, api, worker |
| Database | `db_pool_connections` (`state`), `db_pool_max`, `db_pool_wait_seconds`, `db_query_duration_seconds` (`query`), `db_errors_total` (`error`: a SQLSTATE code, `timeout`, or `connection_lost`) | api, worker |
| Cache | `shop_cache_entries`, `shop_cache_hits_total`, `shop_cache_misses_total` | api |
| Business | `shop_product_views_total`, `shop_cart_adds_total`, `shop_checkouts_total` (`result`), `shop_orders_created_total` | api |
| Orders and receipts | `shop_orders_pending`, `shop_worker_jobs_total`, `shop_worker_job_duration_seconds`, `shop_receipt_uploads_total` (`result`) | worker |
| nginx | `nginx_up`, `nginx_http_requests_total`, `nginx_connections_active` | receipts |
| Runtime | `process_*`, `go_*`, `shop_build_info` | every service |

## Observability

Grafana and Prometheus run in namespace `monitoring`:

```
kubectl -n monitoring port-forward svc/grafana 3000:80            # http://localhost:3000
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090   # http://localhost:9090
```

Grafana has the `Shop` dashboards and Explore. Its CloudWatch data source has the
ALB and RDS metrics.
