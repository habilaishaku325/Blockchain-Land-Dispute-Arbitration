(define-constant DISPUTE_FEE_RATE u5)
(define-constant ARBITRATOR_REWARD_RATE u2)
(define-constant BASIS_POINTS u100)
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))

(define-data-var total-platform-fees uint u0)
(define-data-var total-arbitrator-rewards uint u0)

(define-map arbitrator-rewards
  uint
  uint
)

(define-map arbitrators
  principal
  uint
)

(define-data-var next-arbitrator-id uint u1)

(define-map fee-collections
  uint
  {
    platform-fee: uint,
    arbitrator-pool: uint,
    collected-at: uint
  }
)

(define-private (calculate-fee (amount uint) (rate uint))
  (/ (* amount rate) BASIS_POINTS)
)

(define-public (register-arbitrator (arbitrator principal))
  (let
    (
      (arbitrator-id (var-get next-arbitrator-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? arbitrators arbitrator)) (err u206))
    (map-set arbitrators arbitrator arbitrator-id)
    (var-set next-arbitrator-id (+ arbitrator-id u1))
    (ok arbitrator-id)
  )
)

(define-public (collect-dispute-fees (dispute-id uint) (total-stake uint))
  (let
    (
      (platform-fee (calculate-fee total-stake DISPUTE_FEE_RATE))
      (arbitrator-pool (calculate-fee total-stake ARBITRATOR_REWARD_RATE))
      (total-fees (+ platform-fee arbitrator-pool))
    )
    (asserts! (> total-stake total-fees) (err u200))
    (map-set fee-collections
      dispute-id
      {
        platform-fee: platform-fee,
        arbitrator-pool: arbitrator-pool,
        collected-at: stacks-block-height
      }
    )
    (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
    (var-set total-arbitrator-rewards (+ (var-get total-arbitrator-rewards) arbitrator-pool))
    (ok total-fees)
  )
)

(define-public (distribute-arbitrator-rewards (dispute-id uint) (winning-arbitrator-ids (list 10 uint)))
  (let
    (
      (fee-data (unwrap! (map-get? fee-collections dispute-id) (err u201)))
      (arbitrator-pool (get arbitrator-pool fee-data))
      (num-arbitrators (len winning-arbitrator-ids))
      (reward-per-arbitrator (/ arbitrator-pool num-arbitrators))
    )
    (asserts! (> num-arbitrators u0) (err u202))
    (fold distribute-single-reward winning-arbitrator-ids reward-per-arbitrator)
    (ok true)
  )
)

(define-private (distribute-single-reward (arbitrator-id uint) (reward uint))
  (let
    (
      (current-rewards (default-to u0 (map-get? arbitrator-rewards arbitrator-id)))
    )
    (map-set arbitrator-rewards arbitrator-id (+ current-rewards reward))
    reward
  )
)

(define-public (claim-arbitrator-rewards)
  (let
    (
      (arbitrator-id (unwrap! (map-get? arbitrators tx-sender) (err u203)))
      (pending-rewards (default-to u0 (map-get? arbitrator-rewards arbitrator-id)))
    )
    (asserts! (> pending-rewards u0) (err u204))
    (try! (as-contract (stx-transfer? pending-rewards tx-sender (as-contract tx-sender))))
    (map-delete arbitrator-rewards arbitrator-id)
    (ok pending-rewards)
  )
)

(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get total-platform-fees)) (err u205))
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) CONTRACT_OWNER)))
    (var-set total-platform-fees (- (var-get total-platform-fees) amount))
    (ok amount)
  )
)

(define-read-only (get-arbitrator-pending-rewards (arbitrator-id uint))
  (default-to u0 (map-get? arbitrator-rewards arbitrator-id))
)

(define-read-only (get-dispute-fees (dispute-id uint))
  (map-get? fee-collections dispute-id)
)

(define-read-only (get-platform-fees)
  (var-get total-platform-fees)
)

(define-read-only (get-arbitrator-reward-pool)
  (var-get total-arbitrator-rewards)
)

(define-read-only (get-arbitrator-id (arbitrator principal))
  (map-get? arbitrators arbitrator)
)
