;; Quota Management Contract
;; Enforces sustainable fishing limits

(define-data-var admin principal tx-sender)

;; Reference to catch tracking contract
(define-constant catch-tracking-contract .catch-tracking)

;; Quota structure by species
(define-map quotas
  { species: (string-utf8 30), year: uint }
  { total-limit: uint, used: uint }
)

;; Vessel-specific quotas
(define-map vessel-quotas
  { vessel-id: (string-utf8 36), species: (string-utf8 30), year: uint }
  { limit: uint, used: uint }
)

;; Set global quota for a species
(define-public (set-species-quota (species (string-utf8 30)) (year uint) (limit uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set quotas
      { species: species, year: year }
      { total-limit: limit, used: u0 }
    ))
  )
)

;; Allocate quota to a vessel
(define-public (allocate-vessel-quota
    (vessel-id (string-utf8 36))
    (species (string-utf8 30))
    (year uint)
    (limit uint))
  (let
    ((species-quota (map-get? quotas { species: species, year: year })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some species-quota) (err u404))

    ;; Ensure allocation doesn't exceed total quota
    (asserts! (<= limit (get total-limit (unwrap-panic species-quota))) (err u400))

    (ok (map-set vessel-quotas
      { vessel-id: vessel-id, species: species, year: year }
      { limit: limit, used: u0 }
    ))
  )
)

;; Record catch against quota (called by catch tracking contract)
(define-public (record-catch-against-quota
    (vessel-id (string-utf8 36))
    (species (string-utf8 30))
    (amount uint))
  (let
    ((current-year (get-current-year))
     (vessel-quota (map-get? vessel-quotas { vessel-id: vessel-id, species: species, year: current-year }))
     (species-quota (map-get? quotas { species: species, year: current-year })))

    ;; Check if quotas exist
    (asserts! (is-some vessel-quota) (err u404))
    (asserts! (is-some species-quota) (err u404))

    ;; Check if vessel has enough quota
    (asserts! (<= (+ (get used (unwrap-panic vessel-quota)) amount)
                 (get limit (unwrap-panic vessel-quota)))
             (err u401))

    ;; Update vessel quota
    (map-set vessel-quotas
      { vessel-id: vessel-id, species: species, year: current-year }
      {
        limit: (get limit (unwrap-panic vessel-quota)),
        used: (+ (get used (unwrap-panic vessel-quota)) amount)
      }
    )

    ;; Update species quota
    (map-set quotas
      { species: species, year: current-year }
      {
        total-limit: (get total-limit (unwrap-panic species-quota)),
        used: (+ (get used (unwrap-panic species-quota)) amount)
      }
    )

    (ok true)
  )
)

;; Get current year (simplified)
(define-read-only (get-current-year)
  (let
    ((block-time (get-block-info? time (- block-height u1))))
    ;; Simplified year calculation - in a real contract this would be more accurate
    (/ (default-to u0 block-time) u31536000)
  )
)

;; Check if a vessel has remaining quota for a species
(define-read-only (check-vessel-quota (vessel-id (string-utf8 36)) (species (string-utf8 30)))
  (let
    ((current-year (get-current-year))
     (vessel-quota (map-get? vessel-quotas { vessel-id: vessel-id, species: species, year: current-year })))
    (if (is-some vessel-quota)
      (- (get limit (unwrap-panic vessel-quota)) (get used (unwrap-panic vessel-quota)))
      u0
    )
  )
)

;; Get global quota status for a species
(define-read-only (get-species-quota-status (species (string-utf8 30)))
  (let
    ((current-year (get-current-year))
     (species-quota (map-get? quotas { species: species, year: current-year })))
    (if (is-some species-quota)
      {
        total: (get total-limit (unwrap-panic species-quota)),
        used: (get used (unwrap-panic species-quota)),
        remaining: (- (get total-limit (unwrap-panic species-quota)) (get used (unwrap-panic species-quota)))
      }
      { total: u0, used: u0, remaining: u0 }
    )
  )
)
