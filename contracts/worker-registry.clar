;; title: worker-registry
;; version: 1.0.0
;; summary: Worker profile management and reputation system for gig platform
;; description: Smart contract for managing worker registrations, skills, and reputation scoring

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-WORKER-NOT-FOUND (err u201))
(define-constant ERR-WORKER-EXISTS (err u202))
(define-constant ERR-INVALID-RATING (err u203))
(define-constant ERR-INVALID-SKILL-COUNT (err u204))
(define-constant ERR-SKILL-EXISTS (err u205))
(define-constant ERR-SKILL-NOT-FOUND (err u206))
(define-constant ERR-INSUFFICIENT-EXPERIENCE (err u207))
(define-constant ERR-INVALID-PARAMETERS (err u208))

;; Rating constants
(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)
(define-constant DEFAULT-RATING u3)

;; Experience level constants
(define-constant EXPERIENCE-BEGINNER u0)
(define-constant EXPERIENCE-INTERMEDIATE u1)
(define-constant EXPERIENCE-ADVANCED u2)
(define-constant EXPERIENCE-EXPERT u3)

;; Maximum skills per worker
(define-constant MAX-SKILLS-PER-WORKER u10)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var total-registered-workers uint u0)
(define-data-var minimum-reputation-score uint u0)

;; Worker profile data structure
(define-map worker-profiles
  { worker: principal }
  {
    name: (string-ascii 100),
    bio: (string-ascii 500),
    contact-info: (string-ascii 200),
    hourly-rate: uint,
    availability: bool,
    registered-at: uint,
    last-active: uint,
    experience-level: uint,
    total-jobs-completed: uint,
    total-earnings: uint,
    profile-verified: bool
  }
)

;; Worker skills mapping
(define-map worker-skills
  { worker: principal, skill: (string-ascii 50) }
  {
    proficiency-level: uint,
    years-experience: uint,
    verified: bool,
    added-at: uint
  }
)

;; Worker reputation and ratings
(define-map worker-reputation
  { worker: principal }
  {
    average-rating: uint,
    total-ratings: uint,
    rating-sum: uint,
    five-star-count: uint,
    four-star-count: uint,
    three-star-count: uint,
    two-star-count: uint,
    one-star-count: uint,
    reputation-score: uint
  }
)

;; Individual rating records
(define-map worker-ratings
  { worker: principal, rater: principal, job-id: uint }
  {
    rating: uint,
    review: (string-ascii 300),
    rated-at: uint
  }
)

;; Skill categories for better organization
(define-map skill-categories
  { skill: (string-ascii 50) }
  {
    category: (string-ascii 50),
    description: (string-ascii 200),
    demand-level: uint
  }
)

;; Worker certifications
(define-map worker-certifications
  { worker: principal, certification: (string-ascii 100) }
  {
    issuer: (string-ascii 100),
    issued-date: uint,
    expiry-date: (optional uint),
    verified: bool
  }
)

;; Public function: Register a new worker
(define-public (register-worker 
  (name (string-ascii 100))
  (bio (string-ascii 500))
  (contact-info (string-ascii 200))
  (hourly-rate uint)
  (experience-level uint)
)
  (begin
    (asserts! (is-none (map-get? worker-profiles { worker: tx-sender })) ERR-WORKER-EXISTS)
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETERS)
    (asserts! (<= experience-level EXPERIENCE-EXPERT) ERR-INVALID-PARAMETERS)
    (asserts! (> hourly-rate u0) ERR-INVALID-PARAMETERS)
    
    ;; Create worker profile
    (map-set worker-profiles
      { worker: tx-sender }
      {
        name: name,
        bio: bio,
        contact-info: contact-info,
        hourly-rate: hourly-rate,
        availability: true,
        registered-at: stacks-block-height,
        last-active: stacks-block-height,
        experience-level: experience-level,
        total-jobs-completed: u0,
        total-earnings: u0,
        profile-verified: false
      }
    )
    
    ;; Initialize reputation with default values
    (map-set worker-reputation
      { worker: tx-sender }
      {
        average-rating: DEFAULT-RATING,
        total-ratings: u0,
        rating-sum: u0,
        five-star-count: u0,
        four-star-count: u0,
        three-star-count: u0,
        two-star-count: u0,
        one-star-count: u0,
        reputation-score: u0
      }
    )
    
    ;; Increment total registered workers
    (var-set total-registered-workers (+ (var-get total-registered-workers) u1))
    
    (print { event: "worker-registered", worker: tx-sender, name: name })
    (ok true)
  )
)

;; Public function: Update worker profile
(define-public (update-profile
  (name (string-ascii 100))
  (bio (string-ascii 500))
  (contact-info (string-ascii 200))
  (hourly-rate uint)
  (availability bool)
)
  (let (
    (current-profile (unwrap! (map-get? worker-profiles { worker: tx-sender }) ERR-WORKER-NOT-FOUND))
  )
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> hourly-rate u0) ERR-INVALID-PARAMETERS)
    
    (map-set worker-profiles
      { worker: tx-sender }
      (merge current-profile {
        name: name,
        bio: bio,
        contact-info: contact-info,
        hourly-rate: hourly-rate,
        availability: availability,
        last-active: stacks-block-height
      })
    )
    
    (print { event: "profile-updated", worker: tx-sender })
    (ok true)
  )
)

;; Public function: Add skill to worker profile
(define-public (add-skill
  (skill (string-ascii 50))
  (proficiency-level uint)
  (years-experience uint)
)
  (begin
    (asserts! (is-some (map-get? worker-profiles { worker: tx-sender })) ERR-WORKER-NOT-FOUND)
    (asserts! (is-none (map-get? worker-skills { worker: tx-sender, skill: skill })) ERR-SKILL-EXISTS)
    (asserts! (<= proficiency-level EXPERIENCE-EXPERT) ERR-INVALID-PARAMETERS)
    (asserts! (> (len skill) u0) ERR-INVALID-PARAMETERS)
    
    ;; Check if worker already has maximum skills
    (asserts! (< (get-worker-skill-count tx-sender) MAX-SKILLS-PER-WORKER) ERR-INVALID-SKILL-COUNT)
    
    (map-set worker-skills
      { worker: tx-sender, skill: skill }
      {
        proficiency-level: proficiency-level,
        years-experience: years-experience,
        verified: false,
        added-at: stacks-block-height
      }
    )
    
    (print { event: "skill-added", worker: tx-sender, skill: skill })
    (ok true)
  )
)

;; Public function: Update skill proficiency
(define-public (update-skill
  (skill (string-ascii 50))
  (proficiency-level uint)
  (years-experience uint)
)
  (let (
    (current-skill (unwrap! (map-get? worker-skills { worker: tx-sender, skill: skill }) ERR-SKILL-NOT-FOUND))
  )
    (asserts! (<= proficiency-level EXPERIENCE-EXPERT) ERR-INVALID-PARAMETERS)
    
    (map-set worker-skills
      { worker: tx-sender, skill: skill }
      (merge current-skill {
        proficiency-level: proficiency-level,
        years-experience: years-experience
      })
    )
    
    (print { event: "skill-updated", worker: tx-sender, skill: skill })
    (ok true)
  )
)

;; Public function: Submit worker rating (called by clients)
(define-public (rate-worker
  (worker principal)
  (job-id uint)
  (rating uint)
  (review (string-ascii 300))
)
  (let (
    (current-reputation (unwrap! (map-get? worker-reputation { worker: worker }) ERR-WORKER-NOT-FOUND))
    (new-total-ratings (+ (get total-ratings current-reputation) u1))
    (new-rating-sum (+ (get rating-sum current-reputation) rating))
    (new-average-rating (/ new-rating-sum new-total-ratings))
  )
    (asserts! (is-some (map-get? worker-profiles { worker: worker })) ERR-WORKER-NOT-FOUND)
    (asserts! (and (>= rating MIN-RATING) (<= rating MAX-RATING)) ERR-INVALID-RATING)
    (asserts! (is-none (map-get? worker-ratings { worker: worker, rater: tx-sender, job-id: job-id })) ERR-INVALID-PARAMETERS)
    
    ;; Record the individual rating
    (map-set worker-ratings
      { worker: worker, rater: tx-sender, job-id: job-id }
      {
        rating: rating,
        review: review,
        rated-at: stacks-block-height
      }
    )
    
    ;; Update reputation statistics
    (map-set worker-reputation
      { worker: worker }
      (merge current-reputation {
        average-rating: new-average-rating,
        total-ratings: new-total-ratings,
        rating-sum: new-rating-sum,
        five-star-count: (+ (get five-star-count current-reputation) (if (is-eq rating u5) u1 u0)),
        four-star-count: (+ (get four-star-count current-reputation) (if (is-eq rating u4) u1 u0)),
        three-star-count: (+ (get three-star-count current-reputation) (if (is-eq rating u3) u1 u0)),
        two-star-count: (+ (get two-star-count current-reputation) (if (is-eq rating u2) u1 u0)),
        one-star-count: (+ (get one-star-count current-reputation) (if (is-eq rating u1) u1 u0)),
        reputation-score: (calculate-reputation-score new-average-rating new-total-ratings)
      })
    )
    
    (print { event: "worker-rated", worker: worker, rater: tx-sender, rating: rating })
    (ok true)
  )
)

;; Public function: Update job completion stats
(define-public (update-job-stats
  (worker principal)
  (earnings uint)
)
  (let (
    (current-profile (unwrap! (map-get? worker-profiles { worker: worker }) ERR-WORKER-NOT-FOUND))
  )
    ;; Only allow contract owner to update stats (called from job manager)
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (map-set worker-profiles
      { worker: worker }
      (merge current-profile {
        total-jobs-completed: (+ (get total-jobs-completed current-profile) u1),
        total-earnings: (+ (get total-earnings current-profile) earnings),
        last-active: stacks-block-height
      })
    )
    
    (print { event: "job-stats-updated", worker: worker, earnings: earnings })
    (ok true)
  )
)

;; Public function: Add certification
(define-public (add-certification
  (certification (string-ascii 100))
  (issuer (string-ascii 100))
  (expiry-date (optional uint))
)
  (begin
    (asserts! (is-some (map-get? worker-profiles { worker: tx-sender })) ERR-WORKER-NOT-FOUND)
    (asserts! (> (len certification) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> (len issuer) u0) ERR-INVALID-PARAMETERS)
    
    (map-set worker-certifications
      { worker: tx-sender, certification: certification }
      {
        issuer: issuer,
        issued-date: stacks-block-height,
        expiry-date: expiry-date,
        verified: false
      }
    )
    
    (print { event: "certification-added", worker: tx-sender, certification: certification })
    (ok true)
  )
)

;; Read-only function: Get worker profile
(define-read-only (get-worker-profile (worker principal))
  (map-get? worker-profiles { worker: worker })
)

;; Read-only function: Get worker reputation
(define-read-only (get-worker-reputation (worker principal))
  (map-get? worker-reputation { worker: worker })
)

;; Read-only function: Get worker skill
(define-read-only (get-worker-skill (worker principal) (skill (string-ascii 50)))
  (map-get? worker-skills { worker: worker, skill: skill })
)

;; Read-only function: Get worker rating from specific rater
(define-read-only (get-worker-rating (worker principal) (rater principal) (job-id uint))
  (map-get? worker-ratings { worker: worker, rater: rater, job-id: job-id })
)

;; Read-only function: Get worker certification
(define-read-only (get-worker-certification (worker principal) (certification (string-ascii 100)))
  (map-get? worker-certifications { worker: worker, certification: certification })
)

;; Read-only function: Check if worker is available
(define-read-only (is-worker-available (worker principal))
  (match (map-get? worker-profiles { worker: worker })
    profile (get availability profile)
    false
  )
)

;; Read-only function: Get total registered workers
(define-read-only (get-total-registered-workers)
  (var-get total-registered-workers)
)

;; Read-only function: Get worker skill count (private helper made read-only for testing)
(define-read-only (get-worker-skill-count (worker principal))
  ;; This is a simplified version - in practice would need to iterate through skills
  ;; For now, returns 0 as placeholder
  u0
)

;; Private function: Calculate reputation score based on ratings and other factors
(define-private (calculate-reputation-score (average-rating uint) (total-ratings uint))
  (let (
    (rating-weight (* average-rating u20)) ;; Rating contributes up to 100 points
    (volume-weight (if (> total-ratings u10) u20 (/ total-ratings u10))) ;; Volume contributes up to 20 points
  )
    (+ rating-weight volume-weight)
  )
)

;; Private function: Verify skill proficiency (placeholder for future implementation)
(define-private (verify-skill (worker principal) (skill (string-ascii 50)))
  (match (map-get? worker-skills { worker: worker, skill: skill })
    skill-data (ok (get verified skill-data))
    ERR-SKILL-NOT-FOUND
  )
)
