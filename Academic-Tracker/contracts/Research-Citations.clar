;; Citation Tracking Smart Contract
;; This contract allows users to:
;; 1. Register academic works
;; 2. Add citations between works
;; 3. Track citation metrics
;; 4. Verify authorship
;; 5. Implement citation rewards

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_DOES_NOT_EXIST (err u102))
(define-constant ERR_SELF_CITATION (err u103))
(define-constant ERR_INVALID_PARAMETERS (err u104))
(define-constant ERR_INVALID_INPUT (err u105))

;; Data Structures

;; Academic work information
(define-map academic-works
  { work-id: (string-ascii 64) }
  {
    title: (string-ascii 256),
    author: principal,
    timestamp: uint,
    field: (string-ascii 64),
    abstract: (string-utf8 1024),
    verified: bool
  }
)

;; Citation data
(define-map citation-records
  {
    citing-work: (string-ascii 64),
    cited-work: (string-ascii 64)
  }
  {
    timestamp: uint,
    context: (optional (string-utf8 256)),
    weight: uint
  }
)

;; Citation count per work
(define-map citation-counts
  { work-id: (string-ascii 64) }
  { count: uint }
)

;; Author reputation tracking
(define-map author-stats
  { author: principal }
  {
    total-works: uint,
    total-citations-received: uint,
    reputation-score: uint
  }
)

;; Field-specific citation metrics
(define-map field-metrics
  { field: (string-ascii 64) }
  {
    total-works: uint,
    total-citations: uint
  }
)

;; Reward tracking for citations
(define-map citation-rewards
  { author: principal }
  { reward-points: uint }
)

;; Allowed verifiers
(define-map allowed-verifiers
  { verifier: principal }
  { active: bool }
)

;; Validation functions

;; Validate string-ascii is not empty
(define-private (validate-string-ascii (input (string-ascii 256)))
  (> (len input) u0)
)

;; Validate string-utf8 is not empty (if present)
(define-private (validate-optional-string-utf8 (input (optional (string-utf8 256))))
  (match input
    some-val (> (len some-val) u0)
    true
  )
)

;; Validate work-id
(define-private (validate-work-id (work-id (string-ascii 64)))
  (and
    (> (len work-id) u0)
    (<= (len work-id) u64)
  )
)

;; Validate principal is not null
(define-private (validate-principal (user principal))
  (not (is-eq user 'SPNWZ5V2TPWGQGVDR6T7B6RQ4XMGZ4PXTEE0VQ0S))  ;; Check against zero/null address
)

;; Initialize functions

;; Initialize citation count for a work
(define-private (initialize-citation-count (work-id (string-ascii 64)))
  (map-set citation-counts
    { work-id: work-id }
    { count: u0 }
  )
)

;; Initialize author stats for a new author
(define-private (initialize-author-stats (author principal))
  (let ((author-data (map-get? author-stats { author: author })))
    (if (is-some author-data)
      true
      (map-set author-stats
        { author: author }
        {
          total-works: u0,
          total-citations-received: u0,
          reputation-score: u100
        }
      )
    )
  )
)

;; Initialize field metrics
(define-private (initialize-field-metrics (field (string-ascii 64)))
  (let ((field-data (map-get? field-metrics { field: field })))
    (if (is-some field-data)
      true
      (map-set field-metrics
        { field: field }
        {
          total-works: u0,
          total-citations: u0
        }
      )
    )
  )
)

;; Initialize citation rewards
(define-private (initialize-citation-rewards (author principal))
  (let ((rewards-data (map-get? citation-rewards { author: author })))
    (if (is-some rewards-data)
      true
      (map-set citation-rewards
        { author: author }
        { reward-points: u0 }
      )
    )
  )
)

;; Core Functions

;; Register a new academic work
(define-public (register-work
                (work-id (string-ascii 64))
                (title (string-ascii 256))
                (field (string-ascii 64))
                (abstract (string-utf8 1024)))
  (let
    ((author tx-sender)
     (existing-work (map-get? academic-works { work-id: work-id })))
    (begin
      ;; Validate inputs
      (asserts! (validate-work-id work-id) ERR_INVALID_INPUT)
      (asserts! (validate-string-ascii title) ERR_INVALID_INPUT)
      (asserts! (validate-string-ascii field) ERR_INVALID_INPUT)
      (asserts! (> (len abstract) u0) ERR_INVALID_INPUT)
      
      (asserts! (is-none existing-work) ERR_ALREADY_EXISTS)
      
      ;; Initialize or update author stats
      (initialize-author-stats author)
      (map-set author-stats
        { author: author }
        (merge
          (default-to
            { total-works: u0, total-citations-received: u0, reputation-score: u100 }
            (map-get? author-stats { author: author })
          )
          { total-works: (+ (get total-works (default-to
                               { total-works: u0, total-citations-received: u0, reputation-score: u100 }
                               (map-get? author-stats { author: author })))
                            u1) }
        )
      )
      
      ;; Initialize field metrics
      (initialize-field-metrics field)
      (map-set field-metrics
        { field: field }
        (merge
          (default-to
            { total-works: u0, total-citations: u0 }
            (map-get? field-metrics { field: field })
          )
          { total-works: (+ (get total-works (default-to
                               { total-works: u0, total-citations: u0 }
                               (map-get? field-metrics { field: field })))
                            u1) }
        )
      )
      
      ;; Create work record
      (map-set academic-works
        { work-id: work-id }
        {
          title: title,
          author: author,
          timestamp: block-height,
          field: field,
          abstract: abstract,
          verified: false
        }
      )
      
      ;; Initialize citation count
      (initialize-citation-count work-id)
      
      ;; Initialize citation rewards
      (initialize-citation-rewards author)
      
      (ok true)
    )
  )
)

;; Add a citation between two works
(define-public (add-citation
               (citing-work (string-ascii 64))
               (cited-work (string-ascii 64))
               (context (optional (string-utf8 256)))
               (weight uint))
  (let
    ((citing-work-data (map-get? academic-works { work-id: citing-work }))
     (cited-work-data (map-get? academic-works { work-id: cited-work })))
    (begin
      ;; Validate inputs
      (asserts! (validate-work-id citing-work) ERR_INVALID_INPUT)
      (asserts! (validate-work-id cited-work) ERR_INVALID_INPUT)
      (asserts! (validate-optional-string-utf8 context) ERR_INVALID_INPUT)
      
      ;; Check if works exist
      (asserts! (is-some citing-work-data) ERR_DOES_NOT_EXIST)
      (asserts! (is-some cited-work-data) ERR_DOES_NOT_EXIST)
      
      ;; Check if caller is the author of the citing work
      (asserts! (is-eq tx-sender (get author (unwrap! citing-work-data ERR_DOES_NOT_EXIST))) ERR_NOT_AUTHORIZED)
      
      ;; Prevent self-citation (same work)
      (asserts! (not (is-eq citing-work cited-work)) ERR_SELF_CITATION)
      
      ;; Check valid weight (1-10)
      (asserts! (and (>= weight u1) (<= weight u10)) ERR_INVALID_PARAMETERS)
      
      ;; Record the citation
      (map-set citation-records
        { citing-work: citing-work, cited-work: cited-work }
        {
          timestamp: block-height,
          context: context,
          weight: weight
        }
      )
      
      ;; Update citation count for cited work
      (map-set citation-counts
        { work-id: cited-work }
        { count: (+ (get count (default-to { count: u0 } (map-get? citation-counts { work-id: cited-work }))) u1) }
      )
      
      ;; Update total citations received for cited work's author
      (map-set author-stats
        { author: (get author (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) }
        (merge
          (default-to
            { total-works: u0, total-citations-received: u0, reputation-score: u100 }
            (map-get? author-stats { author: (get author (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) })
          )
          { 
            total-citations-received: (+ 
              (get total-citations-received
                (default-to
                  { total-works: u0, total-citations-received: u0, reputation-score: u100 }
                  (map-get? author-stats { author: (get author (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) })
                )
              )
              u1
            ),
            reputation-score: (+ 
              (get reputation-score
                (default-to
                  { total-works: u0, total-citations-received: u0, reputation-score: u100 }
                  (map-get? author-stats { author: (get author (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) })
                )
              )
              weight
            )
          }
        )
      )
      
      ;; Update field metrics for cited work's field
      (map-set field-metrics
        { field: (get field (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) }
        (merge
          (default-to
            { total-works: u0, total-citations: u0 }
            (map-get? field-metrics { field: (get field (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) })
          )
          { 
            total-citations: (+ 
              (get total-citations
                (default-to
                  { total-works: u0, total-citations: u0 }
                  (map-get? field-metrics { field: (get field (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) })
                )
              )
              u1
            )
          }
        )
      )
      
      ;; Add reward points to cited author
      (map-set citation-rewards
        { author: (get author (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) }
        { 
          reward-points: (+ 
            (get reward-points
              (default-to
                { reward-points: u0 }
                (map-get? citation-rewards { author: (get author (unwrap! cited-work-data ERR_DOES_NOT_EXIST)) })
              )
            )
            weight
          )
        }
      )
      
      (ok true)
    )
  )
)

;; Verify authorship of a work (can only be done by authorized verifiers)
(define-public (verify-work (work-id (string-ascii 64)))
  (let
    ((work-data (map-get? academic-works { work-id: work-id }))
     (verifier-data (map-get? allowed-verifiers { verifier: tx-sender })))
    (begin
      ;; Validate work-id
      (asserts! (validate-work-id work-id) ERR_INVALID_INPUT)
      
      (asserts! (is-some work-data) ERR_DOES_NOT_EXIST)
      (asserts! (is-some verifier-data) ERR_NOT_AUTHORIZED)
      (asserts! (get active (unwrap! verifier-data ERR_NOT_AUTHORIZED)) ERR_NOT_AUTHORIZED)
      
      (map-set academic-works
        { work-id: work-id }
        (merge (unwrap! work-data ERR_DOES_NOT_EXIST) { verified: true })
      )
      
      ;; Bonus reputation for verified works
      (map-set author-stats
        { author: (get author (unwrap! work-data ERR_DOES_NOT_EXIST)) }
        (merge
          (default-to
            { total-works: u0, total-citations-received: u0, reputation-score: u100 }
            (map-get? author-stats { author: (get author (unwrap! work-data ERR_DOES_NOT_EXIST)) })
          )
          { 
            reputation-score: (+ 
              (get reputation-score
                (default-to
                  { total-works: u0, total-citations-received: u0, reputation-score: u100 }
                  (map-get? author-stats { author: (get author (unwrap! work-data ERR_DOES_NOT_EXIST)) })
                )
              )
              u50
            )
          }
        )
      )
      
      (ok true)
    )
  )
)

;; Add a verifier (contract owner only)
(define-public (add-verifier (verifier principal))
  (begin
    ;; Validate verifier input
    (asserts! (validate-principal verifier) ERR_INVALID_INPUT)
    
    ;; Validate verifier is not tx-sender (avoid self-authorization)
    (asserts! (not (is-eq verifier tx-sender)) ERR_INVALID_INPUT)
    
    ;; Check authorization
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Check if already exists and active
    (let ((existing-verifier (map-get? allowed-verifiers { verifier: verifier })))
      (asserts! (or (is-none existing-verifier) 
                    (not (get active (default-to { active: false } existing-verifier)))) 
                ERR_ALREADY_EXISTS)
    )
    
    ;; Add verifier
    (map-set allowed-verifiers
      { verifier: verifier }
      { active: true }
    )
    (ok true)
  )
)

;; Remove a verifier (contract owner only)
(define-public (remove-verifier (verifier principal))
  (begin
    ;; Validate verifier input
    (asserts! (validate-principal verifier) ERR_INVALID_INPUT)
    
    ;; Check authorization
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Validate verifier exists and is active
    (let ((existing-verifier (map-get? allowed-verifiers { verifier: verifier })))
      (asserts! (is-some existing-verifier) ERR_DOES_NOT_EXIST)
      (asserts! (get active (default-to { active: false } existing-verifier)) ERR_DOES_NOT_EXIST)
    )
    
    ;; Deactivate verifier
    (map-set allowed-verifiers
      { verifier: verifier }
      { active: false }
    )
    (ok true)
  )
)

;; Claim citation rewards
(define-public (claim-rewards)
  (let
    ((author tx-sender)
     (rewards (default-to { reward-points: u0 } (map-get? citation-rewards { author: author }))))
    (begin
      (asserts! (> (get reward-points rewards) u0) ERR_INVALID_PARAMETERS)
      
      ;; Reset reward points (In a real implementation, this would transfer tokens)
      (map-set citation-rewards
        { author: author }
        { reward-points: u0 }
      )
      
      (ok (get reward-points rewards))
    )
  )
)

;; Read-only functions

;; Get work details
(define-read-only (get-work-details (work-id (string-ascii 64)))
  (map-get? academic-works { work-id: work-id })
)

;; Get citation details
(define-read-only (get-citation-details (citing-work (string-ascii 64)) (cited-work (string-ascii 64)))
  (map-get? citation-records { citing-work: citing-work, cited-work: cited-work })
)

;; Get citation count for a work
(define-read-only (get-citation-count (work-id (string-ascii 64)))
  (default-to { count: u0 } (map-get? citation-counts { work-id: work-id }))
)

;; Get author stats
(define-read-only (get-author-stats (author principal))
  (default-to 
    { total-works: u0, total-citations-received: u0, reputation-score: u0 }
    (map-get? author-stats { author: author })
  )
)

;; Get field metrics
(define-read-only (get-field-metrics (field (string-ascii 64)))
  (default-to
    { total-works: u0, total-citations: u0 }
    (map-get? field-metrics { field: field })
  )
)

;; Get reward points for an author
(define-read-only (get-reward-points (author principal))
  (get reward-points (default-to { reward-points: u0 } (map-get? citation-rewards { author: author })))
)

;; Get h-index for an author (simplified implementation)
(define-read-only (get-h-index (author principal))
  (let
    ((author-data (map-get? author-stats { author: author })))
    (if (is-some author-data)
      ;; Simple approximation based on total citations
      (let
        ((citations (get total-citations-received (unwrap! author-data (err u0))))
         (works (get total-works (unwrap! author-data (err u0)))))
        (if (and (> citations u0) (> works u0))
          ;; Very simplified h-index approximation
          (ok (if (> citations u100) 
                u10
                (if (> citations u81)
                  u9
                  (if (> citations u64)
                    u8
                    (if (> citations u49)
                      u7
                      (if (> citations u36)
                        u6
                        (if (> citations u25)
                          u5
                          (if (> citations u16)
                            u4
                            (if (> citations u9)
                              u3
                              (if (> citations u4)
                                u2
                                u1
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              ))
          (ok u0)
        )
      )
      (err u0)
    )
  )
)

;; Check if a user is a verifier
(define-read-only (is-verifier (verifier principal))
  (let
    ((verifier-data (map-get? allowed-verifiers { verifier: verifier })))
    (if (is-some verifier-data)
      (get active (unwrap! verifier-data false))
      false
    )
  )
)

;; Get all citations for a work
(define-read-only (get-citations-for-work (work-id (string-ascii 64)) (as-cited bool))
  (if as-cited
    ;; Get all citations where this work is cited
    (get-citations-for-cited-work work-id u0)
    ;; Get all citations where this work cites others
    (get-citations-for-citing-work work-id u0)
  )
)

;; Helper functions for pagination (would need modification for real implementation)
(define-private (get-citations-for-cited-work (work-id (string-ascii 64)) (index uint))
  (ok "Citations would be returned here with pagination")
)

(define-private (get-citations-for-citing-work (work-id (string-ascii 64)) (index uint))
  (ok "Citations would be returned here with pagination")
)