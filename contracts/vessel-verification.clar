;; Vessel Verification Contract
;; Validates registered fishing boats

(define-data-var admin principal tx-sender)

;; Vessel status: 0 = unverified, 1 = verified, 2 = suspended
(define-map vessels
  { vessel-id: (string-utf8 36) }
  {
    owner: principal,
    name: (string-utf8 50),
    size: uint,
    vessel-type: (string-utf8 20),
    registration-date: uint,
    status: uint
  }
)

;; Register a new vessel
(define-public (register-vessel
    (vessel-id (string-utf8 36))
    (name (string-utf8 50))
    (size uint)
    (vessel-type (string-utf8 20)))
  (let
    ((registration-date (get-block-info? time (- block-height u1))))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-none (map-get? vessels { vessel-id: vessel-id })) (err u100))
    (ok (map-set vessels
      { vessel-id: vessel-id }
      {
        owner: tx-sender,
        name: name,
        size: size,
        vessel-type: vessel-type,
        registration-date: (default-to u0 registration-date),
        status: u0
      }
    ))
  )
)

;; Verify a vessel (admin only)
(define-public (verify-vessel (vessel-id (string-utf8 36)))
  (let
    ((vessel (map-get? vessels { vessel-id: vessel-id })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some vessel) (err u404))
    (ok (map-set vessels
      { vessel-id: vessel-id }
      (merge (unwrap-panic vessel) { status: u1 })
    ))
  )
)

;; Suspend a vessel (admin only)
(define-public (suspend-vessel (vessel-id (string-utf8 36)))
  (let
    ((vessel (map-get? vessels { vessel-id: vessel-id })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some vessel) (err u404))
    (ok (map-set vessels
      { vessel-id: vessel-id }
      (merge (unwrap-panic vessel) { status: u2 })
    ))
  )
)

;; Check if a vessel is verified
(define-read-only (is-vessel-verified (vessel-id (string-utf8 36)))
  (let
    ((vessel (map-get? vessels { vessel-id: vessel-id })))
    (if (and (is-some vessel) (is-eq (get status (unwrap-panic vessel)) u1))
      true
      false
    )
  )
)

;; Get vessel details
(define-read-only (get-vessel-details (vessel-id (string-utf8 36)))
  (map-get? vessels { vessel-id: vessel-id })
)

;; Transfer vessel ownership
(define-public (transfer-vessel-ownership
    (vessel-id (string-utf8 36))
    (new-owner principal))
  (let
    ((vessel (map-get? vessels { vessel-id: vessel-id })))
    (asserts! (is-some vessel) (err u404))
    (asserts! (is-eq (get owner (unwrap-panic vessel)) tx-sender) (err u403))
    (ok (map-set vessels
      { vessel-id: vessel-id }
      (merge (unwrap-panic vessel) { owner: new-owner })
    ))
  )
)
