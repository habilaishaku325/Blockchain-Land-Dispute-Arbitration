(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_APPEAL_NOT_FOUND (err u401))
(define-constant ERR_APPEAL_EXPIRED (err u402))
(define-constant ERR_ALREADY_APPEALED (err u403))
(define-constant ERR_INSUFFICIENT_STAKE (err u404))
(define-constant ERR_NOT_SENIOR_ARBITRATOR (err u405))
(define-constant ERR_ALREADY_VOTED_APPEAL (err u406))

(define-constant APPEAL_WINDOW u1008)
(define-constant APPEAL_DURATION u2016)
(define-constant MIN_APPEAL_STAKE u5000000)

(define-data-var appeal-counter uint u0)
(define-data-var senior-arbitrator-counter uint u0)

(define-map appeals
  uint
  {
    dispute-id: uint,
    appellant: principal,
    respondent: principal,
    appeal-reason: (string-ascii 300),
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    stake-amount: uint,
    votes-uphold: uint,
    votes-overturn: uint,
    resolved-at: (optional uint),
    outcome: (optional (string-ascii 20))
  }
)

(define-map senior-arbitrators
  uint
  {
    address: principal,
    cases-decided: uint,
    success-rate: uint,
    active: bool,
    appointed-at: uint
  }
)

(define-map senior-arbitrator-lookup
  principal
  uint
)

(define-map appeal-votes
  {appeal-id: uint, arbitrator-id: uint}
  {
    vote: (string-ascii 20),
    reasoning: (string-ascii 200),
    voted-at: uint
  }
)

(define-public (register-senior-arbitrator (arbitrator principal) (success-rate uint))
  (let
    (
      (arbitrator-id (+ (var-get senior-arbitrator-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= success-rate u80) ERR_UNAUTHORIZED)
    (map-set senior-arbitrators
      arbitrator-id
      {
        address: arbitrator,
        cases-decided: u0,
        success-rate: success-rate,
        active: true,
        appointed-at: stacks-block-height
      }
    )
    (map-set senior-arbitrator-lookup arbitrator arbitrator-id)
    (var-set senior-arbitrator-counter arbitrator-id)
    (ok arbitrator-id)
  )
)

(define-public (file-appeal (dispute-id uint) (respondent principal) (appeal-reason (string-ascii 300)) (stake-amount uint))
  (let
    (
      (appeal-id (+ (var-get appeal-counter) u1))
      (current-height stacks-block-height)
    )
    (asserts! (>= stake-amount MIN_APPEAL_STAKE) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? appeals dispute-id)) ERR_ALREADY_APPEALED)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set appeals
      appeal-id
      {
        dispute-id: dispute-id,
        appellant: tx-sender,
        respondent: respondent,
        appeal-reason: appeal-reason,
        created-at: current-height,
        expires-at: (+ current-height APPEAL_DURATION),
        status: "pending",
        stake-amount: stake-amount,
        votes-uphold: u0,
        votes-overturn: u0,
        resolved-at: none,
        outcome: none
      }
    )
    (var-set appeal-counter appeal-id)
    (ok appeal-id)
  )
)

(define-public (vote-on-appeal (appeal-id uint) (vote (string-ascii 20)) (reasoning (string-ascii 200)))
  (let
    (
      (appeal (unwrap! (map-get? appeals appeal-id) ERR_APPEAL_NOT_FOUND))
      (arbitrator-id (unwrap! (map-get? senior-arbitrator-lookup tx-sender) ERR_NOT_SENIOR_ARBITRATOR))
      (arbitrator (unwrap! (map-get? senior-arbitrators arbitrator-id) ERR_NOT_SENIOR_ARBITRATOR))
    )
    (asserts! (< stacks-block-height (get expires-at appeal)) ERR_APPEAL_EXPIRED)
    (asserts! (get active arbitrator) ERR_NOT_SENIOR_ARBITRATOR)
    (asserts! (is-none (map-get? appeal-votes {appeal-id: appeal-id, arbitrator-id: arbitrator-id})) ERR_ALREADY_VOTED_APPEAL)
    (asserts! (or (is-eq vote "uphold") (is-eq vote "overturn")) ERR_UNAUTHORIZED)
    
    (map-set appeal-votes
      {appeal-id: appeal-id, arbitrator-id: arbitrator-id}
      {
        vote: vote,
        reasoning: reasoning,
        voted-at: stacks-block-height
      }
    )
    
    (let
      (
        (updated-appeal
          (if (is-eq vote "uphold")
            (merge appeal {votes-uphold: (+ (get votes-uphold appeal) u1)})
            (merge appeal {votes-overturn: (+ (get votes-overturn appeal) u1)})
          )
        )
      )
      (map-set appeals appeal-id updated-appeal)
      (map-set senior-arbitrators
        arbitrator-id
        (merge arbitrator {cases-decided: (+ (get cases-decided arbitrator) u1)})
      )
    )
    (ok true)
  )
)

(define-public (resolve-appeal (appeal-id uint))
  (let
    (
      (appeal (unwrap! (map-get? appeals appeal-id) ERR_APPEAL_NOT_FOUND))
      (total-votes (+ (get votes-uphold appeal) (get votes-overturn appeal)))
    )
    (asserts! (>= total-votes u3) ERR_UNAUTHORIZED)
    (let
      (
        (outcome
          (if (> (get votes-overturn appeal) (get votes-uphold appeal))
            "overturned"
            "upheld"
          )
        )
        (winner
          (if (> (get votes-overturn appeal) (get votes-uphold appeal))
            (get appellant appeal)
            (get respondent appeal)
          )
        )
      )
      (try! (as-contract (stx-transfer? (get stake-amount appeal) tx-sender winner)))
      (map-set appeals
        appeal-id
        (merge appeal {
          status: "resolved",
          resolved-at: (some stacks-block-height),
          outcome: (some outcome)
        })
      )
    )
    (ok true)
  )
)

(define-read-only (get-appeal (appeal-id uint))
  (map-get? appeals appeal-id)
)

(define-read-only (get-senior-arbitrator (arbitrator-id uint))
  (map-get? senior-arbitrators arbitrator-id)
)

(define-read-only (can-appeal (dispute-id uint) (dispute-resolved-at uint))
  (< (- stacks-block-height dispute-resolved-at) APPEAL_WINDOW)
)