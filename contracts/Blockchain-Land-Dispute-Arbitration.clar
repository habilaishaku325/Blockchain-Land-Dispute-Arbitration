(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_DISPUTE_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_NOT_ARBITRATOR (err u104))
(define-constant ERR_INSUFFICIENT_STAKE (err u105))
(define-constant ERR_DISPUTE_CLOSED (err u106))

(define-data-var dispute-counter uint u0)
(define-data-var arbitrator-counter uint u0)
(define-data-var min-stake uint u1000000)

(define-map disputes
  uint
  {
    claimant: principal,
    defendant: principal,
    land-id: (string-ascii 50),
    description: (string-ascii 500),
    claimant-evidence: (list 5 (string-ascii 200)),
    defendant-evidence: (list 5 (string-ascii 200)),
    status: (string-ascii 20),
    created-at: uint,
    resolved-at: (optional uint),
    winner: (optional principal),
    total-votes-claimant: uint,
    total-votes-defendant: uint,
    stake-amount: uint
  }
)

(define-map arbitrators
  uint
  {
    address: principal,
    reputation: uint,
    total-cases: uint,
    active: bool,
    registered-at: uint
  }
)

(define-map arbitrator-votes
  {dispute-id: uint, arbitrator-id: uint}
  {
    vote: (string-ascii 20),
    reasoning: (string-ascii 300),
    voted-at: uint
  }
)

(define-map user-stakes
  {dispute-id: uint, user: principal}
  uint
)

(define-map arbitrator-lookup
  principal
  uint
)

(define-public (register-arbitrator)
  (let
    (
      (arbitrator-id (+ (var-get arbitrator-counter) u1))
    )
    (asserts! (is-none (map-get? arbitrator-lookup tx-sender)) ERR_UNAUTHORIZED)
    (map-set arbitrators
      arbitrator-id
      {
        address: tx-sender,
        reputation: u100,
        total-cases: u0,
        active: true,
        registered-at: stacks-block-height
      }
    )
    (map-set arbitrator-lookup tx-sender arbitrator-id)
    (var-set arbitrator-counter arbitrator-id)
    (ok arbitrator-id)
  )
)

(define-public (create-dispute (defendant principal) (land-id (string-ascii 50)) (description (string-ascii 500)) (stake-amount uint))
  (let
    (
      (dispute-id (+ (var-get dispute-counter) u1))
    )
    (asserts! (>= stake-amount (var-get min-stake)) ERR_INSUFFICIENT_STAKE)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set disputes
      dispute-id
      {
        claimant: tx-sender,
        defendant: defendant,
        land-id: land-id,
        description: description,
        claimant-evidence: (list),
        defendant-evidence: (list),
        status: "open",
        created-at: stacks-block-height,
        resolved-at: none,
        winner: none,
        total-votes-claimant: u0,
        total-votes-defendant: u0,
        stake-amount: stake-amount
      }
    )
    (map-set user-stakes {dispute-id: dispute-id, user: tx-sender} stake-amount)
    (var-set dispute-counter dispute-id)
    (ok dispute-id)
  )
)

(define-public (add-defendant-stake (dispute-id uint) (stake-amount uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get defendant dispute)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dispute) "open") ERR_DISPUTE_CLOSED)
    (asserts! (>= stake-amount (var-get min-stake)) ERR_INSUFFICIENT_STAKE)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set user-stakes {dispute-id: dispute-id, user: tx-sender} stake-amount)
    (map-set disputes
      dispute-id
      (merge dispute {status: "evidence"})
    )
    (ok true)
  )
)

(define-public (submit-evidence (dispute-id uint) (evidence (string-ascii 200)))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    )
    (asserts! (is-eq (get status dispute) "evidence") ERR_INVALID_STATUS)
    (if (is-eq tx-sender (get claimant dispute))
      (begin
        (map-set disputes
          dispute-id
          (merge dispute {
            claimant-evidence: (unwrap-panic (as-max-len? (append (get claimant-evidence dispute) evidence) u5))
          })
        )
        (ok true)
      )
      (if (is-eq tx-sender (get defendant dispute))
        (begin
          (map-set disputes
            dispute-id
            (merge dispute {
              defendant-evidence: (unwrap-panic (as-max-len? (append (get defendant-evidence dispute) evidence) u5))
            })
          )
          (ok true)
        )
        ERR_UNAUTHORIZED
      )
    )
  )
)
(define-public (start-arbitration (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get claimant dispute)) (is-eq tx-sender (get defendant dispute))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dispute) "evidence") ERR_INVALID_STATUS)
    (map-set disputes
      dispute-id
      (merge dispute {status: "arbitration"})
    )
    (ok true)
  )
)

(define-public (cast-vote (dispute-id uint) (vote (string-ascii 20)) (reasoning (string-ascii 300)))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (arbitrator-id (unwrap! (map-get? arbitrator-lookup tx-sender) ERR_NOT_ARBITRATOR))
      (arbitrator (unwrap! (map-get? arbitrators arbitrator-id) ERR_NOT_ARBITRATOR))
    )
    (asserts! (is-eq (get status dispute) "arbitration") ERR_INVALID_STATUS)
    (asserts! (get active arbitrator) ERR_NOT_ARBITRATOR)
    (asserts! (is-none (map-get? arbitrator-votes {dispute-id: dispute-id, arbitrator-id: arbitrator-id})) ERR_ALREADY_VOTED)
    (asserts! (or (is-eq vote "claimant") (is-eq vote "defendant")) ERR_INVALID_STATUS)
    
    (map-set arbitrator-votes
      {dispute-id: dispute-id, arbitrator-id: arbitrator-id}
      {
        vote: vote,
        reasoning: reasoning,
        voted-at: stacks-block-height
      }
    )
    
    (let
      (
        (updated-dispute
          (if (is-eq vote "claimant")
            (merge dispute {total-votes-claimant: (+ (get total-votes-claimant dispute) u1)})
            (merge dispute {total-votes-defendant: (+ (get total-votes-defendant dispute) u1)})
          )
        )
      )
      (map-set disputes dispute-id updated-dispute)
      (map-set arbitrators
        arbitrator-id
        (merge arbitrator {total-cases: (+ (get total-cases arbitrator) u1)})
      )
    )
    (ok true)
  )
)

(define-public (finalize-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (total-votes (+ (get total-votes-claimant dispute) (get total-votes-defendant dispute)))
    )
    (asserts! (is-eq (get status dispute) "arbitration") ERR_INVALID_STATUS)
    (asserts! (>= total-votes u3) ERR_INVALID_STATUS)
    
    (let
      (
        (winner
          (if (> (get total-votes-claimant dispute) (get total-votes-defendant dispute))
            (get claimant dispute)
            (get defendant dispute)
          )
        )
        (loser
          (if (> (get total-votes-claimant dispute) (get total-votes-defendant dispute))
            (get defendant dispute)
            (get claimant dispute)
          )
        )
        (winner-stake (default-to u0 (map-get? user-stakes {dispute-id: dispute-id, user: winner})))
        (loser-stake (default-to u0 (map-get? user-stakes {dispute-id: dispute-id, user: loser})))
        (total-payout (+ winner-stake loser-stake))
      )
      (try! (as-contract (stx-transfer? total-payout tx-sender winner)))
      (map-set disputes
        dispute-id
        (merge dispute {
          status: "resolved",
          resolved-at: (some stacks-block-height),
          winner: (some winner)
        })
      )
    )
    (ok true)
  )
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-arbitrator (arbitrator-id uint))
  (map-get? arbitrators arbitrator-id)
)

(define-read-only (get-arbitrator-by-address (address principal))
  (match (map-get? arbitrator-lookup address)
    arbitrator-id (map-get? arbitrators arbitrator-id)
    none
  )
)

(define-read-only (get-vote (dispute-id uint) (arbitrator-id uint))
  (map-get? arbitrator-votes {dispute-id: dispute-id, arbitrator-id: arbitrator-id})
)

(define-read-only (get-user-stake (dispute-id uint) (user principal))
  (map-get? user-stakes {dispute-id: dispute-id, user: user})
)

(define-read-only (get-dispute-count)
  (var-get dispute-counter)
)

(define-read-only (get-arbitrator-count)
  (var-get arbitrator-counter)
)

(define-public (update-min-stake (new-stake uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set min-stake new-stake)
    (ok true)
  )
)

(define-public (deactivate-arbitrator (arbitrator-id uint))
  (let
    (
      (arbitrator (unwrap! (map-get? arbitrators arbitrator-id) ERR_NOT_ARBITRATOR))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set arbitrators
      arbitrator-id
      (merge arbitrator {active: false})
    )
    (ok true)
  )
)
