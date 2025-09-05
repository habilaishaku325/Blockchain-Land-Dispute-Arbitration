(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_TEMPLATE_NOT_FOUND (err u301))
(define-constant ERR_TEMPLATE_EXISTS (err u302))
(define-constant ERR_INVALID_CATEGORY (err u303))

(define-data-var template-counter uint u0)

(define-map dispute-templates
  uint
  {
    name: (string-ascii 100),
    category: (string-ascii 30),
    description: (string-ascii 300),
    required-evidence: (list 8 (string-ascii 100)),
    guidelines: (string-ascii 500),
    min-stake-multiplier: uint,
    created-at: uint,
    active: bool
  }
)

(define-map template-usage
  uint
  uint
)

(define-map category-templates
  (string-ascii 30)
  (list 20 uint)
)

(define-private (is-valid-category (category (string-ascii 30)))
  (or
    (is-eq category "boundary")
    (is-eq category "ownership")
    (is-eq category "easement")
    (is-eq category "encroachment")
    (is-eq category "access-rights")
  )
)

(define-public (create-template 
  (name (string-ascii 100))
  (category (string-ascii 30))
  (description (string-ascii 300))
  (required-evidence (list 8 (string-ascii 100)))
  (guidelines (string-ascii 500))
  (min-stake-multiplier uint))
  (let
    (
      (template-id (+ (var-get template-counter) u1))
      (current-templates (default-to (list) (map-get? category-templates category)))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-category category) ERR_INVALID_CATEGORY)
    (map-set dispute-templates
      template-id
      {
        name: name,
        category: category,
        description: description,
        required-evidence: required-evidence,
        guidelines: guidelines,
        min-stake-multiplier: min-stake-multiplier,
        created-at: stacks-block-height,
        active: true
      }
    )
    (map-set category-templates
      category
      (unwrap-panic (as-max-len? (append current-templates template-id) u20))
    )
    (map-set template-usage template-id u0)
    (var-set template-counter template-id)
    (ok template-id)
  )
)

(define-public (use-template (template-id uint))
  (let
    (
      (template (unwrap! (map-get? dispute-templates template-id) ERR_TEMPLATE_NOT_FOUND))
      (current-usage (default-to u0 (map-get? template-usage template-id)))
    )
    (asserts! (get active template) ERR_TEMPLATE_NOT_FOUND)
    (map-set template-usage template-id (+ current-usage u1))
    (ok true)
  )
)

(define-public (deactivate-template (template-id uint))
  (let
    (
      (template (unwrap! (map-get? dispute-templates template-id) ERR_TEMPLATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set dispute-templates
      template-id
      (merge template {active: false})
    )
    (ok true)
  )
)

(define-read-only (get-template (template-id uint))
  (map-get? dispute-templates template-id)
)

(define-read-only (get-templates-by-category (category (string-ascii 30)))
  (map-get? category-templates category)
)

(define-read-only (get-template-usage (template-id uint))
  (default-to u0 (map-get? template-usage template-id))
)

(define-read-only (get-template-count)
  (var-get template-counter)
)