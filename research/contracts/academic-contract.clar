;; Scientific Research Consortium - Stage 1
;; Basic academic institution registration and simple research proposal system

;; Constants
(define-constant principal-investigator tx-sender)
(define-constant err-pi-only (err u300))
(define-constant err-not-faculty (err u301))
(define-constant err-invalid-study (err u302))
(define-constant err-institution-not-registered (err u303))

;; Data Variables
(define-data-var research-counter uint u0)
(define-data-var consortium-fee uint u1000000) ;; 1 STX fee for research proposals

;; Data Maps

;; Academic institutions in the consortium
(define-map academic-institutions 
  { institution-id: uint }
  {
    institution-name: (string-ascii 50),
    lead-contact: principal,
    is-active: bool
  }
)

;; Research studies
(define-map research-studies
  { study-id: uint }
  {
    research-title: (string-ascii 100),
    hypothesis: (string-ascii 300),
    lead-researcher: principal,
    institution-id: uint,
    study-start: uint,
    study-duration: uint,
    is-completed: bool
  }
)

;; Faculty members
(define-map faculty-members
  { faculty-address: principal }
  {
    institution-id: uint,
    faculty-name: (string-ascii 50),
    expertise-level: uint,
    is-verified: bool
  }
)

;; Public Functions

;; Register academic institution
(define-public (register-institution 
  (institution-name (string-ascii 50))
  (lead-contact principal))
  (let ((institution-id (+ (var-get research-counter) u1)))
    (map-set academic-institutions
      { institution-id: institution-id }
      {
        institution-name: institution-name,
        lead-contact: lead-contact,
        is-active: true
      }
    )
    (var-set research-counter institution-id)
    (ok institution-id)
  )
)

;; Register faculty member
(define-public (register-faculty
  (institution-id uint)
  (faculty-name (string-ascii 50))
  (expertise-level uint))
  (let (
    (institution (unwrap! (map-get? academic-institutions { institution-id: institution-id }) err-institution-not-registered))
  )
    ;; Only institution lead can register faculty
    (asserts! (is-eq tx-sender (get lead-contact institution)) err-not-faculty)
    
    (map-set faculty-members
      { faculty-address: tx-sender }
      {
        institution-id: institution-id,
        faculty-name: faculty-name,
        expertise-level: expertise-level,
        is-verified: true
      }
    )
    (ok true)
  )
)

;; Submit research proposal
(define-public (submit-research-proposal
  (research-title (string-ascii 100))
  (hypothesis (string-ascii 300))
  (institution-id uint)
  (study-duration uint))
  (let (
    (study-id (+ (var-get research-counter) u1))
    (faculty (unwrap! (map-get? faculty-members { faculty-address: tx-sender }) err-not-faculty))
  )
    ;; Validate institution exists
    (asserts! (is-some (map-get? academic-institutions { institution-id: institution-id })) err-institution-not-registered)
    
    ;; Validate faculty belongs to institution
    (asserts! (is-eq (get institution-id faculty) institution-id) err-not-faculty)
    
    ;; Pay consortium fee
    (try! (stx-transfer? (var-get consortium-fee) tx-sender principal-investigator))
    
    ;; Create research study
    (map-set research-studies
      { study-id: study-id }
      {
        research-title: research-title,
        hypothesis: hypothesis,
        lead-researcher: tx-sender,
        institution-id: institution-id,
        study-start: block-height,
        study-duration: study-duration,
        is-completed: false
      }
    )
    
    (var-set research-counter study-id)
    (ok study-id)
  )
)

;; Complete research study
(define-public (complete-study (study-id uint))
  (let (
    (study (unwrap! (map-get? research-studies { study-id: study-id }) err-invalid-study))
  )
    ;; Only lead researcher can complete study
    (asserts! (is-eq tx-sender (get lead-researcher study)) err-pi-only)
    
    ;; Mark study as completed
    (map-set research-studies
      { study-id: study-id }
      (merge study { is-completed: true })
    )
    
    (ok true)
  )
)

;; Update consortium fee
(define-public (update-consortium-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender principal-investigator) err-pi-only)
    (var-set consortium-fee new-fee)
    (ok true)
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

;; Get faculty member info
(define-read-only (get-faculty-info (faculty-address principal))
  (map-get? faculty-members { faculty-address: faculty-address })
)

;; Get current consortium fee
(define-read-only (get-consortium-fee)
  (var-get consortium-fee)
)

;; Get total registered entities
(define-read-only (get-research-counter)
  (var-get research-counter)
)

;; Check if address is verified faculty
(define-read-only (is-verified-faculty (faculty-address principal))
  (match (map-get? faculty-members { faculty-address: faculty-address })
    faculty-data (get is-verified faculty-data)
    false
  )
)