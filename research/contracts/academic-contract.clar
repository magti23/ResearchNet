;; Scientific Research Consortium - Stage 2
;; Advanced collaborative research with peer review, funding allocation, and multi-institutional support

;; Constants
(define-constant principal-investigator tx-sender)
(define-constant err-pi-only (err u300))
(define-constant err-not-faculty (err u301))
(define-constant err-invalid-study (err u302))
(define-constant err-study-expired (err u303))
(define-constant err-already-reviewed (err u304))
(define-constant err-insufficient-consensus (err u305))
(define-constant err-study-not-approved (err u306))
(define-constant err-institution-not-registered (err u307))
(define-constant err-invalid-funding (err u308))

;; Data Variables
(define-data-var research-counter uint u0)
(define-data-var consortium-fee uint u2000000) ;; 2 STX fee for research proposals

;; Data Maps

;; Academic institutions in the consortium
(define-map academic-institutions 
  { institution-id: uint }
  {
    institution-name: (string-ascii 50),
    accreditation-token: principal,
    faculty-threshold: uint,
    research-fund: principal,
    is-accredited: bool
  }
)

;; Collaborative research studies
(define-map research-studies
  { study-id: uint }
  {
    research-title: (string-ascii 100),
    hypothesis: (string-ascii 500),
    lead-researcher: principal,
    collaborating-institutions: (list 10 uint),
    funding-distribution: (list 10 { institution-id: uint, allocation: uint }),
    study-commencement: uint,
    deadline: uint,
    peer-review-threshold: uint,
    is-published: bool,
    research-field: (string-ascii 20) ;; "medicine", "physics", "biology"
  }
)

;; Institutional peer reviews
(define-map peer-reviews
  { study-id: uint, institution-id: uint }
  {
    approvals: uint,
    rejections: uint,
    total-faculty-input: uint,
    consensus-reached: bool,
    institutional-verdict: (optional bool) ;; true = approve, false = reject
  }
)

;; Faculty member reviews
(define-map faculty-reviews
  { study-id: uint, institution-id: uint, reviewer: principal }
  {
    review-decision: bool, ;; true = approve, false = reject
    expertise-weight: uint,
    review-timestamp: uint
  }
)

;; Research funding commitments
(define-map funding-commitments
  { study-id: uint, institution-id: uint }
  {
    committed-funds: uint,
    funds-locked: bool,
    release-criteria: (string-ascii 50)
  }
)

;; Research initiatives
(define-map research-initiatives
  { initiative-id: uint }
  {
    initiative-name: (string-ascii 100),
    participating-institutions: (list 10 uint),
    total-funding: uint,
    initiative-status: (string-ascii 20), ;; "active", "concluded", "suspended"
    start-date: uint
  }
)

;; Public Functions

;; Register academic institution
(define-public (establish-academic-partnership 
  (institution-name (string-ascii 50))
  (accreditation-token principal)
  (faculty-threshold uint)
  (research-fund principal))
  (let ((institution-id (+ (var-get research-counter) u1)))
    (asserts! (> faculty-threshold u0) err-invalid-funding)
    (map-set academic-institutions
      { institution-id: institution-id }
      {
        institution-name: institution-name,
        accreditation-token: accreditation-token,
        faculty-threshold: faculty-threshold,
        research-fund: research-fund,
        is-accredited: true
      }
    )
    (var-set research-counter institution-id)
    (ok institution-id)
  )
)

;; Submit collaborative research proposal
(define-public (submit-research-proposal
  (research-title (string-ascii 100))
  (hypothesis (string-ascii 500))
  (collaborating-institutions (list 10 uint))
  (funding-distribution (list 10 { institution-id: uint, allocation: uint }))
  (study-duration uint)
  (peer-review-threshold uint)
  (research-field (string-ascii 20)))
  (let (
    (study-id (+ (var-get research-counter) u1))
    (study-commencement block-height)
    (deadline (+ block-height study-duration))
  )
    ;; Validate all institutions are registered
    (asserts! (is-ok (validate-institutions collaborating-institutions)) err-institution-not-registered)
    
    ;; Pay consortium fee
    (try! (stx-transfer? (var-get consortium-fee) tx-sender principal-investigator))
    
    ;; Create research study
    (map-set research-studies
      { study-id: study-id }
      {
        research-title: research-title,
        hypothesis: hypothesis,
        lead-researcher: tx-sender,
        collaborating-institutions: collaborating-institutions,
        funding-distribution: funding-distribution,
        study-commencement: study-commencement,
        deadline: deadline,
        peer-review-threshold: peer-review-threshold,
        is-published: false,
        research-field: research-field
      }
    )
    
    ;; Initialize peer review process
    (map initialize-peer-review collaborating-institutions)
    
    (var-set research-counter study-id)
    (ok study-id)
  )
)

;; Faculty member submits peer review
(define-public (submit-peer-review 
  (study-id uint)
  (institution-id uint)
  (review-decision bool)
  (expertise-weight uint))
  (let (
    (study (unwrap! (map-get? research-studies { study-id: study-id }) err-invalid-study))
    (institution-info (unwrap! (map-get? academic-institutions { institution-id: institution-id }) err-institution-not-registered))
    (existing-review (map-get? faculty-reviews { study-id: study-id, institution-id: institution-id, reviewer: tx-sender }))
  )
    ;; Validate study is under review
    (asserts! (and (>= block-height (get study-commencement study)) 
                   (<= block-height (get deadline study))) err-study-expired)
    
    ;; Ensure faculty hasn't reviewed yet
    (asserts! (is-none existing-review) err-already-reviewed)
    
    ;; Validate faculty credentials
    (asserts! (>= expertise-weight (get faculty-threshold institution-info)) err-not-faculty)
    
    ;; Record faculty review
    (map-set faculty-reviews
      { study-id: study-id, institution-id: institution-id, reviewer: tx-sender }
      {
        review-decision: review-decision,
        expertise-weight: expertise-weight,
        review-timestamp: block-height
      }
    )
    
    ;; Update institutional review totals
    (try! (update-institutional-review study-id institution-id review-decision expertise-weight))
    
    (ok true)
  )
)

;; Publish approved research study
(define-public (publish-research-findings (study-id uint))
  (let (
    (study (unwrap! (map-get? research-studies { study-id: study-id }) err-invalid-study))
  )
    ;; Validate study hasn't been published
    (asserts! (not (get is-published study)) err-invalid-study)
    
    ;; Validate study review period ended
    (asserts! (> block-height (get deadline study)) err-study-expired)
    
    ;; Check if study was approved
    (asserts! (has-study-been-approved study-id) err-study-not-approved)
    
    ;; Mark as published
    (map-set research-studies
      { study-id: study-id }
      (merge study { is-published: true })
    )
    
    ;; Release research funding
    (try! (release-research-funding study-id (get funding-distribution study)))
    
    (ok true)
  )
)

;; Commit institutional research funds
(define-public (commit-research-funding 
  (study-id uint)
  (institution-id uint)
  (funding-amount uint))
  (let (
    (institution-info (unwrap! (map-get? academic-institutions { institution-id: institution-id }) err-institution-not-registered))
  )
    ;; Validate caller represents institution
    (asserts! (is-eq tx-sender (get research-fund institution-info)) err-not-faculty)
    
    ;; Lock research funds
    (map-set funding-commitments
      { study-id: study-id, institution-id: institution-id }
      {
        committed-funds: funding-amount,
        funds-locked: true,
        release-criteria: "peer-review-approval"
      }
    )
    
    (ok true)
  )
)

;; Launch research initiative
(define-public (launch-research-initiative
  (initiative-name (string-ascii 100))
  (participating-institutions (list 10 uint))
  (total-funding uint))
  (let ((initiative-id (+ (var-get research-counter) u1)))
    ;; Validate all institutions are registered
    (asserts! (is-ok (validate-institutions participating-institutions)) err-institution-not-registered)
    
    ;; Only principal investigator can launch initiatives
    (asserts! (is-eq tx-sender principal-investigator) err-pi-only)
    
    ;; Create research initiative
    (map-set research-initiatives
      { initiative-id: initiative-id }
      {
        initiative-name: initiative-name,
        participating-institutions: participating-institutions,
        total-funding: total-funding,
        initiative-status: "active",
        start-date: block-height
      }
    )
    
    (var-set research-counter initiative-id)
    (ok initiative-id)
  )
)

;; Private Functions

;; Validate all collaborating institutions
(define-private (validate-institutions (institution-list (list 10 uint)))
  (fold check-institution-exists institution-list (ok true))
)

(define-private (check-institution-exists (institution-id uint) (previous-result (response bool uint)))
  (match previous-result
    success (if (is-some (map-get? academic-institutions { institution-id: institution-id }))
              (ok true)
              err-institution-not-registered)
    error (err error)
  )
)

;; Initialize peer review process
(define-private (initialize-peer-review (institution-id uint))
  (let ((study-id (var-get research-counter)))
    (map-set peer-reviews
      { study-id: study-id, institution-id: institution-id }
      {
        approvals: u0,
        rejections: u0,
        total-faculty-input: u0,
        consensus-reached: false,
        institutional-verdict: none
      }
    )
  )
)

;; Update institutional review totals
(define-private (update-institutional-review 
  (study-id uint)
  (institution-id uint)
  (review-decision bool)
  (expertise-weight uint))
  (let (
    (current-reviews (unwrap! (map-get? peer-reviews { study-id: study-id, institution-id: institution-id }) err-invalid-study))
    (new-approvals (if review-decision (+ (get approvals current-reviews) expertise-weight) (get approvals current-reviews)))
    (new-rejections (if review-decision (get rejections current-reviews) (+ (get rejections current-reviews) expertise-weight)))
    (new-total (+ (get total-faculty-input current-reviews) expertise-weight))
    (study (unwrap! (map-get? research-studies { study-id: study-id }) err-invalid-study))
    (threshold (get peer-review-threshold study))
  )
    ;; Update review counts
    (map-set peer-reviews
      { study-id: study-id, institution-id: institution-id }
      (merge current-reviews {
        approvals: new-approvals,
        rejections: new-rejections,
        total-faculty-input: new-total,
        consensus-reached: (>= new-total threshold),
        institutional-verdict: (if (>= new-total threshold)
                                (some (> new-approvals new-rejections))
                                none)
      })
    )
    (ok true)
  )
)

;; Check if study received sufficient approval
(define-private (has-study-been-approved (study-id uint))
  (let (
    (study (unwrap! (map-get? research-studies { study-id: study-id }) false))
    (institutions (get collaborating-institutions study))
  )
    (check-institutional-approvals study-id institutions)
  )
)

;; Check institutional approvals
(define-private (check-institutional-approvals (study-id uint) (institutions (list 10 uint)))
  (fold check-single-approval institutions true)
)

(define-private (check-single-approval (institution-id uint) (all-approved bool))
  (if all-approved
    (match (map-get? peer-reviews { study-id: (var-get research-counter), institution-id: institution-id })
      review-data (and (get consensus-reached review-data)
                      (unwrap! (get institutional-verdict review-data) false))
      false)
    false)
)

;; Release research funding
(define-private (release-research-funding 
  (study-id uint)
  (funding-allocations (list 10 { institution-id: uint, allocation: uint })))
  (fold process-funding-release funding-allocations (ok true))
)

(define-private (process-funding-release 
  (allocation { institution-id: uint, allocation: uint })
  (previous-result (response bool uint)))
  (match previous-result
    success (let (
      (institution-id (get institution-id allocation))
      (funding-amount (get allocation allocation))
      (commitment (map-get? funding-commitments { study-id: (var-get research-counter), institution-id: institution-id }))
    )
      (match commitment
        commitment-data (if (get funds-locked commitment-data)
                         (begin
                           (map-set funding-commitments
                             { study-id: (var-get research-counter), institution-id: institution-id }
                             (merge commitment-data { funds-locked: false })
                           )
                           (ok true))
                         (ok true))
        (ok true)))
    error (err error)
  )
)

;; Read-only Functions

;; Get research study details
(define-read-only (get-study-details (study-id uint))
  (map-get? research-studies { study-id: study-id })
)

;; Get institution information
(define-read-only (get-institution-info (institution-id uint))
  (map-get? academic-institutions { institution-id: institution-id })
)

;; Get institutional review status
(define-read-only (get-institutional-review (study-id uint) (institution-id uint))
  (map-get? peer-reviews { study-id: study-id, institution-id: institution-id })
)

;; Get faculty review
(define-read-only (get-faculty-review (study-id uint) (institution-id uint) (reviewer principal))
  (map-get? faculty-reviews { study-id: study-id, institution-id: institution-id, reviewer: reviewer })
)

;; Get funding commitment
(define-read-only (get-funding-commitment (study-id uint) (institution-id uint))
  (map-get? funding-commitments { study-id: study-id, institution-id: institution-id })
)

;; Get research initiative
(define-read-only (get-research-initiative (initiative-id uint))
  (map-get? research-initiatives { initiative-id: initiative-id })
)

;; Check if faculty can review
(define-read-only (can-faculty-review (study-id uint) (institution-id uint) (faculty principal))
  (let (
    (study (map-get? research-studies { study-id: study-id }))
    (existing-review (map-get? faculty-reviews { study-id: study-id, institution-id: institution-id, reviewer: faculty }))
  )
    (match study
      study-data (and 
        (>= block-height (get study-commencement study-data))
        (<= block-height (get deadline study-data))
        (is-none existing-review)
        (is-some (map-get? academic-institutions { institution-id: institution-id })))
      false
    )
  )
)

;; Get consortium metrics
(define-read-only (get-consortium-metrics)
  {
    total-entities: (var-get research-counter),
    consortium-fee: (var-get consortium-fee),
    principal-investigator: principal-investigator
  }
)