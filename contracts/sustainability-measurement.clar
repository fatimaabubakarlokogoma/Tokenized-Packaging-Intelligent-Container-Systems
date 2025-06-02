;; Sustainability Measurement Contract
;; Evaluates intelligent packaging environmental impact

;; Constants
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_CONTAINER_NOT_FOUND (err u401))
(define-constant ERR_INVALID_METRICS (err u402))
(define-constant ERR_METRICS_ALREADY_RECORDED (err u403))

;; Data Variables
(define-data-var next-measurement-id uint u1)

;; Data Maps
(define-map sustainability-metrics
  { container-id: uint }
  {
    carbon-footprint: uint,
    recyclability-score: uint,
    energy-efficiency: uint,
    material-sustainability: uint,
    last-updated: uint,
    reporter: principal
  }
)

(define-map measurement-history
  { measurement-id: uint }
  {
    container-id: uint,
    carbon-footprint: uint,
    recyclability-score: uint,
    measurement-date: uint,
    reporter: principal
  }
)

(define-map container-sustainability-score
  { container-id: uint }
  {
    overall-score: uint,
    grade: (string-ascii 10),
    last-calculated: uint
  }
)

;; Public Functions

;; Record sustainability metrics for a container
(define-public (record-metrics (container-id uint) (carbon-footprint uint) (recyclability-score uint))
  (let
    (
      (measurement-id (var-get next-measurement-id))
      (existing-metrics (map-get? sustainability-metrics { container-id: container-id }))
    )
    (asserts! (<= carbon-footprint u1000) ERR_INVALID_METRICS)
    (asserts! (<= recyclability-score u100) ERR_INVALID_METRICS)

    ;; Record in history
    (map-set measurement-history
      { measurement-id: measurement-id }
      {
        container-id: container-id,
        carbon-footprint: carbon-footprint,
        recyclability-score: recyclability-score,
        measurement-date: block-height,
        reporter: tx-sender
      }
    )

    ;; Update current metrics
    (map-set sustainability-metrics
      { container-id: container-id }
      {
        carbon-footprint: carbon-footprint,
        recyclability-score: recyclability-score,
        energy-efficiency: u75, ;; Default value
        material-sustainability: u80, ;; Default value
        last-updated: block-height,
        reporter: tx-sender
      }
    )

    (var-set next-measurement-id (+ measurement-id u1))
    (ok measurement-id)
  )
)

;; Update energy efficiency metrics
(define-public (update-energy-efficiency (container-id uint) (energy-efficiency uint))
  (let
    (
      (existing-metrics (unwrap! (map-get? sustainability-metrics { container-id: container-id }) ERR_CONTAINER_NOT_FOUND))
    )
    (asserts! (<= energy-efficiency u100) ERR_INVALID_METRICS)

    (map-set sustainability-metrics
      { container-id: container-id }
      (merge existing-metrics {
        energy-efficiency: energy-efficiency,
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Update material sustainability score
(define-public (update-material-sustainability (container-id uint) (material-score uint))
  (let
    (
      (existing-metrics (unwrap! (map-get? sustainability-metrics { container-id: container-id }) ERR_CONTAINER_NOT_FOUND))
    )
    (asserts! (<= material-score u100) ERR_INVALID_METRICS)

    (map-set sustainability-metrics
      { container-id: container-id }
      (merge existing-metrics {
        material-sustainability: material-score,
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Calculate overall sustainability score
(define-public (calculate-sustainability-score (container-id uint))
  (let
    (
      (metrics (unwrap! (map-get? sustainability-metrics { container-id: container-id }) ERR_CONTAINER_NOT_FOUND))
      (carbon-score (- u100 (/ (get carbon-footprint metrics) u10)))
      (recyclability (get recyclability-score metrics))
      (energy (get energy-efficiency metrics))
      (material (get material-sustainability metrics))
      (overall-score (/ (+ carbon-score recyclability energy material) u4))
      (grade (if (>= overall-score u90) "A+"
               (if (>= overall-score u80) "A"
                 (if (>= overall-score u70) "B"
                   (if (>= overall-score u60) "C"
                     "D")))))
    )
    (map-set container-sustainability-score
      { container-id: container-id }
      {
        overall-score: overall-score,
        grade: grade,
        last-calculated: block-height
      }
    )
    (ok overall-score)
  )
)

;; Read-only Functions

;; Get sustainability metrics for a container
(define-read-only (get-sustainability-metrics (container-id uint))
  (map-get? sustainability-metrics { container-id: container-id })
)

;; Get measurement history record
(define-read-only (get-measurement-history (measurement-id uint))
  (map-get? measurement-history { measurement-id: measurement-id })
)

;; Get sustainability score
(define-read-only (get-sustainability-score (container-id uint))
  (map-get? container-sustainability-score { container-id: container-id })
)

;; Calculate carbon footprint reduction percentage
(define-read-only (calculate-carbon-reduction (container-id uint) (baseline-footprint uint))
  (match (map-get? sustainability-metrics { container-id: container-id })
    metrics
      (let
        (
          (current-footprint (get carbon-footprint metrics))
          (reduction (if (> baseline-footprint current-footprint)
                      (- baseline-footprint current-footprint)
                      u0))
        )
        (some (/ (* reduction u100) baseline-footprint))
      )
    none
  )
)

;; Check if container meets sustainability standards
(define-read-only (meets-sustainability-standards (container-id uint))
  (match (map-get? container-sustainability-score { container-id: container-id })
    score-data (>= (get overall-score score-data) u70)
    false
  )
)

;; Get total measurements count
(define-read-only (get-total-measurements)
  (- (var-get next-measurement-id) u1)
)
