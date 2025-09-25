;; title: gig-job-manager
;; version: 1.0.0
;; summary: Blockchain-enabled gig worker job management and payment system
;; description: Smart contract for managing gig jobs, escrow payments, and worker assignments

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-JOB-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-ALREADY-APPLIED (err u104))
(define-constant ERR-NOT-ASSIGNED (err u105))
(define-constant ERR-PAYMENT-FAILED (err u106))
(define-constant ERR-JOB-EXPIRED (err u107))
(define-constant ERR-INVALID-RATING (err u108))

;; Job status constants
(define-constant JOB-STATUS-OPEN u0)
(define-constant JOB-STATUS-ASSIGNED u1)
(define-constant JOB-STATUS-IN-PROGRESS u2)
(define-constant JOB-STATUS-COMPLETED u3)
(define-constant JOB-STATUS-PAID u4)
(define-constant JOB-STATUS-CANCELLED u5)

;; Minimum escrow amount in microSTX
(define-constant MIN-ESCROW-AMOUNT u1000000)

;; Maximum job duration in blocks (30 days approx)
(define-constant MAX-JOB-DURATION u4320)

;; Data variables
(define-data-var next-job-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee-rate uint u250) ;; 2.5% platform fee

;; Job data structure
(define-map jobs
  { job-id: uint }
  {
    client: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    payment-amount: uint,
    escrow-amount: uint,
    assigned-worker: (optional principal),
    status: uint,
    created-at: uint,
    deadline: uint,
    completion-requested-at: (optional uint),
    skills-required: (list 5 (string-ascii 50))
  }
)

;; Job applications
(define-map job-applications
  { job-id: uint, worker: principal }
  {
    applied-at: uint,
    proposal: (string-ascii 300),
    proposed-timeline: uint
  }
)

;; Client ratings for workers
(define-map client-ratings
  { job-id: uint }
  {
    worker-rating: uint,
    client-rating: uint,
    worker-review: (string-ascii 200),
    client-review: (string-ascii 200),
    rated-at: uint
  }
)

;; Escrow balances
(define-map escrow-balances
  { job-id: uint }
  { amount: uint }
)

;; Public function: Create a new job posting
(define-public (create-job 
  (title (string-ascii 100)) 
  (description (string-ascii 500))
  (payment-amount uint)
  (duration-blocks uint)
  (skills-required (list 5 (string-ascii 50)))
)
  (let (
    (job-id (var-get next-job-id))
    (escrow-amount (+ payment-amount (/ (* payment-amount (var-get platform-fee-rate)) u10000)))
    (deadline (+ stacks-block-height duration-blocks))
  )
    (asserts! (>= payment-amount MIN-ESCROW-AMOUNT) ERR-INSUFFICIENT-PAYMENT)
    (asserts! (<= duration-blocks MAX-JOB-DURATION) ERR-INVALID-STATUS)
    (asserts! (> (len title) u0) ERR-INVALID-STATUS)
    
    ;; Transfer escrow to contract
    (try! (stx-transfer? escrow-amount tx-sender (as-contract tx-sender)))
    
    ;; Create job entry
    (map-set jobs
      { job-id: job-id }
      {
        client: tx-sender,
        title: title,
        description: description,
        payment-amount: payment-amount,
        escrow-amount: escrow-amount,
        assigned-worker: none,
        status: JOB-STATUS-OPEN,
        created-at: stacks-block-height,
        deadline: deadline,
        completion-requested-at: none,
        skills-required: skills-required
      }
    )
    
    ;; Set escrow balance
    (map-set escrow-balances
      { job-id: job-id }
      { amount: escrow-amount }
    )
    
    ;; Increment job ID counter
    (var-set next-job-id (+ job-id u1))
    
    (print { event: "job-created", job-id: job-id, client: tx-sender, payment: payment-amount })
    (ok job-id)
  )
)

;; Public function: Apply for a job
(define-public (apply-for-job 
  (job-id uint) 
  (proposal (string-ascii 300))
  (timeline-blocks uint)
)
  (let (
    (job-data (unwrap! (map-get? jobs { job-id: job-id }) ERR-JOB-NOT-FOUND))
  )
    (asserts! (is-eq (get status job-data) JOB-STATUS-OPEN) ERR-INVALID-STATUS)
    (asserts! (< stacks-block-height (get deadline job-data)) ERR-JOB-EXPIRED)
    (asserts! (is-none (map-get? job-applications { job-id: job-id, worker: tx-sender })) ERR-ALREADY-APPLIED)
    (asserts! (> timeline-blocks u0) ERR-INVALID-STATUS)
    
    ;; Record application
    (map-set job-applications
      { job-id: job-id, worker: tx-sender }
      {
        applied-at: stacks-block-height,
        proposal: proposal,
        proposed-timeline: timeline-blocks
      }
    )
    
    (print { event: "job-application", job-id: job-id, worker: tx-sender })
    (ok true)
  )
)

;; Public function: Assign job to worker
(define-public (assign-job (job-id uint) (worker principal))
  (let (
    (job-data (unwrap! (map-get? jobs { job-id: job-id }) ERR-JOB-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get client job-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status job-data) JOB-STATUS-OPEN) ERR-INVALID-STATUS)
    (asserts! (is-some (map-get? job-applications { job-id: job-id, worker: worker })) ERR-NOT-AUTHORIZED)
    
    ;; Update job status and assign worker
    (map-set jobs
      { job-id: job-id }
      (merge job-data {
        assigned-worker: (some worker),
        status: JOB-STATUS-ASSIGNED
      })
    )
    
    (print { event: "job-assigned", job-id: job-id, worker: worker, client: tx-sender })
    (ok true)
  )
)

;; Public function: Start work on assigned job
(define-public (start-job (job-id uint))
  (let (
    (job-data (unwrap! (map-get? jobs { job-id: job-id }) ERR-JOB-NOT-FOUND))
    (assigned-worker (unwrap! (get assigned-worker job-data) ERR-NOT-ASSIGNED))
  )
    (asserts! (is-eq tx-sender assigned-worker) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status job-data) JOB-STATUS-ASSIGNED) ERR-INVALID-STATUS)
    
    ;; Update job status to in progress
    (map-set jobs
      { job-id: job-id }
      (merge job-data { status: JOB-STATUS-IN-PROGRESS })
    )
    
    (print { event: "job-started", job-id: job-id, worker: tx-sender })
    (ok true)
  )
)

;; Public function: Request job completion
(define-public (request-completion (job-id uint))
  (let (
    (job-data (unwrap! (map-get? jobs { job-id: job-id }) ERR-JOB-NOT-FOUND))
    (assigned-worker (unwrap! (get assigned-worker job-data) ERR-NOT-ASSIGNED))
  )
    (asserts! (is-eq tx-sender assigned-worker) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status job-data) JOB-STATUS-IN-PROGRESS) ERR-INVALID-STATUS)
    
    ;; Update job status and completion request timestamp
    (map-set jobs
      { job-id: job-id }
      (merge job-data {
        status: JOB-STATUS-COMPLETED,
        completion-requested-at: (some stacks-block-height)
      })
    )
    
    (print { event: "completion-requested", job-id: job-id, worker: tx-sender })
    (ok true)
  )
)

;; Public function: Approve completion and release payment
(define-public (approve-and-pay (job-id uint) (worker-rating uint))
  (let (
    (job-data (unwrap! (map-get? jobs { job-id: job-id }) ERR-JOB-NOT-FOUND))
    (assigned-worker (unwrap! (get assigned-worker job-data) ERR-NOT-ASSIGNED))
    (escrow-data (unwrap! (map-get? escrow-balances { job-id: job-id }) ERR-JOB-NOT-FOUND))
    (platform-fee (/ (* (get payment-amount job-data) (var-get platform-fee-rate)) u10000))
    (worker-payment (get payment-amount job-data))
  )
    (asserts! (is-eq tx-sender (get client job-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status job-data) JOB-STATUS-COMPLETED) ERR-INVALID-STATUS)
    (asserts! (and (>= worker-rating u1) (<= worker-rating u5)) ERR-INVALID-RATING)
    
    ;; Release payment to worker
    (try! (as-contract (stx-transfer? worker-payment tx-sender assigned-worker)))
    
    ;; Pay platform fee to contract owner
    (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get contract-owner))))
    
    ;; Update job status
    (map-set jobs
      { job-id: job-id }
      (merge job-data { status: JOB-STATUS-PAID })
    )
    
    ;; Clear escrow balance
    (map-delete escrow-balances { job-id: job-id })
    
    (print { 
      event: "payment-released", 
      job-id: job-id, 
      worker: assigned-worker, 
      amount: worker-payment,
      rating: worker-rating
    })
    (ok true)
  )
)

;; Public function: Cancel job (only if not assigned or in progress)
(define-public (cancel-job (job-id uint))
  (let (
    (job-data (unwrap! (map-get? jobs { job-id: job-id }) ERR-JOB-NOT-FOUND))
    (escrow-data (unwrap! (map-get? escrow-balances { job-id: job-id }) ERR-JOB-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get client job-data)) ERR-NOT-AUTHORIZED)
    (asserts! (or 
      (is-eq (get status job-data) JOB-STATUS-OPEN)
      (is-eq (get status job-data) JOB-STATUS-ASSIGNED)
    ) ERR-INVALID-STATUS)
    
    ;; Return escrow to client
    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get client job-data))))
    
    ;; Update job status
    (map-set jobs
      { job-id: job-id }
      (merge job-data { status: JOB-STATUS-CANCELLED })
    )
    
    ;; Clear escrow
    (map-delete escrow-balances { job-id: job-id })
    
    (print { event: "job-cancelled", job-id: job-id, client: tx-sender })
    (ok true)
  )
)

;; Read-only function: Get job details
(define-read-only (get-job (job-id uint))
  (map-get? jobs { job-id: job-id })
)

;; Read-only function: Get job application
(define-read-only (get-application (job-id uint) (worker principal))
  (map-get? job-applications { job-id: job-id, worker: worker })
)

;; Read-only function: Get escrow balance
(define-read-only (get-escrow-balance (job-id uint))
  (map-get? escrow-balances { job-id: job-id })
)

;; Read-only function: Get next job ID
(define-read-only (get-next-job-id)
  (var-get next-job-id)
)

;; Read-only function: Check if job is active
(define-read-only (is-job-active (job-id uint))
  (match (map-get? jobs { job-id: job-id })
    job-data (and 
      (not (is-eq (get status job-data) JOB-STATUS-CANCELLED))
      (not (is-eq (get status job-data) JOB-STATUS-PAID))
    )
    false
  )
)

;; Read-only function: Get platform fee rate
(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

;; Private function: Calculate platform fee
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)
