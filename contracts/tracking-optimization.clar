;; Tracking Optimization Contract
;; Enhances intelligent container monitoring and location tracking

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_CONTAINER_NOT_FOUND (err u301))
(define-constant ERR_INVALID_LOCATION (err u302))
(define-constant ERR_INVALID_TIMESTAMP (err u303))

;; Data Variables
(define-data-var next-tracking-id uint u1)

;; Data Maps
(define-map tracking-records
  { tracking-id: uint }
  {
    container-id: uint,
    location: (string-ascii 100),
    timestamp: uint,
    status: (string-ascii 50),
    reporter: principal
  }
)

(define-map container-current-location
  { container-id: uint }
  {
    location: (string-ascii 100),
    last-update: uint,
    status: (string-ascii 50)
  }
)

(define-map container-tracking-history
  { container-id: uint, sequence: uint }
  { tracking-id: uint }
)

(define-map container-tracking-count
  { container-id: uint }
  { count: uint }
)

;; Public Functions

;; Update container location
(define-public (update-location (container-id uint) (location (string-ascii 100)) (timestamp uint))
  (let
    (
      (tracking-id (var-get next-tracking-id))
      (current-count (default-to u0 (get count (map-get? container-tracking-count { container-id: container-id }))))
    )
    (asserts! (> (len location) u0) ERR_INVALID_LOCATION)
    (asserts! (> timestamp u0) ERR_INVALID_TIMESTAMP)

    ;; Create tracking record
    (map-set tracking-records
      { tracking-id: tracking-id }
      {
        container-id: container-id,
        location: location,
        timestamp: timestamp,
        status: "in-transit",
        reporter: tx-sender
      }
    )

    ;; Update current location
    (map-set container-current-location
      { container-id: container-id }
      {
        location: location,
        last-update: timestamp,
        status: "in-transit"
      }
    )

    ;; Add to tracking history
    (map-set container-tracking-history
      { container-id: container-id, sequence: current-count }
      { tracking-id: tracking-id }
    )

    ;; Update tracking count
    (map-set container-tracking-count
      { container-id: container-id }
      { count: (+ current-count u1) }
    )

    (var-set next-tracking-id (+ tracking-id u1))
    (ok tracking-id)
  )
)

;; Update container status
(define-public (update-status (container-id uint) (status (string-ascii 50)))
  (let
    (
      (current-location-data (map-get? container-current-location { container-id: container-id }))
    )
    (asserts! (> (len status) u0) ERR_INVALID_LOCATION)

    (match current-location-data
      location-data
        (map-set container-current-location
          { container-id: container-id }
          (merge location-data { status: status })
        )
        (map-set container-current-location
          { container-id: container-id }
          {
            location: "unknown",
            last-update: block-height,
            status: status
          }
        )
    )
    (ok true)
  )
)

;; Record delivery confirmation
(define-public (confirm-delivery (container-id uint) (delivery-location (string-ascii 100)))
  (let
    (
      (tracking-id (var-get next-tracking-id))
      (current-count (default-to u0 (get count (map-get? container-tracking-count { container-id: container-id }))))
    )
    (asserts! (> (len delivery-location) u0) ERR_INVALID_LOCATION)

    ;; Create delivery record
    (map-set tracking-records
      { tracking-id: tracking-id }
      {
        container-id: container-id,
        location: delivery-location,
        timestamp: block-height,
        status: "delivered",
        reporter: tx-sender
      }
    )

    ;; Update current location to delivered
    (map-set container-current-location
      { container-id: container-id }
      {
        location: delivery-location,
        last-update: block-height,
        status: "delivered"
      }
    )

    ;; Add to tracking history
    (map-set container-tracking-history
      { container-id: container-id, sequence: current-count }
      { tracking-id: tracking-id }
    )

    ;; Update tracking count
    (map-set container-tracking-count
      { container-id: container-id }
      { count: (+ current-count u1) }
    )

    (var-set next-tracking-id (+ tracking-id u1))
    (ok tracking-id)
  )
)

;; Read-only Functions

;; Get current container location
(define-read-only (get-current-location (container-id uint))
  (map-get? container-current-location { container-id: container-id })
)

;; Get tracking record
(define-read-only (get-tracking-record (tracking-id uint))
  (map-get? tracking-records { tracking-id: tracking-id })
)

;; Get tracking history entry
(define-read-only (get-tracking-history (container-id uint) (sequence uint))
  (match (map-get? container-tracking-history { container-id: container-id, sequence: sequence })
    history-entry (map-get? tracking-records { tracking-id: (get tracking-id history-entry) })
    none
  )
)

;; Get tracking count for container
(define-read-only (get-tracking-count (container-id uint))
  (default-to u0 (get count (map-get? container-tracking-count { container-id: container-id })))
)

;; Check if container is delivered
(define-read-only (is-container-delivered (container-id uint))
  (match (map-get? container-current-location { container-id: container-id })
    location-data (is-eq (get status location-data) "delivered")
    false
  )
)

;; Get total tracking records
(define-read-only (get-total-tracking-records)
  (- (var-get next-tracking-id) u1)
)
