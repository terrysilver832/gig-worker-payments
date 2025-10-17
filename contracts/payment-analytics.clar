;; Payment Analytics Contract
;; Tracks payment patterns, statistics, and provides insights for gig worker payments
;; Independent contract with no cross-contract dependencies

;; Error constants (Clarity v3 requirement)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_PAYMENT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CATEGORY (err u103))
(define-constant ERR_INVALID_TIME_RANGE (err u104))

;; Data maps and variables
(define-data-var total-payments-processed uint u0)
(define-data-var total-volume uint u0)
(define-data-var contract-owner principal tx-sender)

;; Payment categories for analytics
(define-constant CATEGORY_WEB_DEV u1)
(define-constant CATEGORY_DESIGN u2)
(define-constant CATEGORY_WRITING u3)
(define-constant CATEGORY_MARKETING u4)
(define-constant CATEGORY_OTHER u5)

;; Daily payment statistics
(define-map daily-stats
    { date: uint }
    {
        payment-count: uint,
        total-volume: uint,
        avg-payment: uint,
        categories: (list 5 uint)
    }
)

;; Payment records for analytics
(define-map payment-records
    { payment-id: uint }
    {
        amount: uint,
        category: uint,
        timestamp: uint,
        payer: principal,
        receiver: principal,
        completed: bool
    }
)

;; Category statistics
(define-map category-stats
    { category: uint }
    {
        total-payments: uint,
        total-volume: uint,
        avg-amount: uint,
        last-payment-time: uint
    }
)

;; User payment history aggregation
(define-map user-payment-stats
    { user: principal }
    {
        payments-sent: uint,
        payments-received: uint,
        volume-sent: uint,
        volume-received: uint,
        avg-sent: uint,
        avg-received: uint
    }
)

;; Auto-incrementing payment ID
(define-data-var next-payment-id uint u1)

;; Private helper functions

(define-private (get-current-date)
    ;; Simplified date calculation (days since epoch)
    (/ block-height u144) ;; Assuming ~144 blocks per day
)

(define-private (is-valid-category (category uint))
    (and 
        (>= category u1)
        (<= category u5)
    )
)

(define-private (update-category-stats (category uint) (amount uint))
    (let (
        (current-stats (default-to 
            { total-payments: u0, total-volume: u0, avg-amount: u0, last-payment-time: u0 }
            (map-get? category-stats { category: category })
        ))
    )
        (map-set category-stats
            { category: category }
            {
                total-payments: (+ (get total-payments current-stats) u1),
                total-volume: (+ (get total-volume current-stats) amount),
                avg-amount: (/ (+ (get total-volume current-stats) amount) 
                             (+ (get total-payments current-stats) u1)),
                last-payment-time: block-height
            }
        )
    )
)

(define-private (update-user-stats (payer principal) (receiver principal) (amount uint))
    (let (
        (payer-stats (default-to 
            { payments-sent: u0, payments-received: u0, volume-sent: u0, 
              volume-received: u0, avg-sent: u0, avg-received: u0 }
            (map-get? user-payment-stats { user: payer })
        ))
        (receiver-stats (default-to 
            { payments-sent: u0, payments-received: u0, volume-sent: u0, 
              volume-received: u0, avg-sent: u0, avg-received: u0 }
            (map-get? user-payment-stats { user: receiver })
        ))
    )
        ;; Update payer stats
        (map-set user-payment-stats
            { user: payer }
            {
                payments-sent: (+ (get payments-sent payer-stats) u1),
                payments-received: (get payments-received payer-stats),
                volume-sent: (+ (get volume-sent payer-stats) amount),
                volume-received: (get volume-received payer-stats),
                avg-sent: (/ (+ (get volume-sent payer-stats) amount) 
                           (+ (get payments-sent payer-stats) u1)),
                avg-received: (get avg-received payer-stats)
            }
        )
        
        ;; Update receiver stats
        (map-set user-payment-stats
            { user: receiver }
            {
                payments-sent: (get payments-sent receiver-stats),
                payments-received: (+ (get payments-received receiver-stats) u1),
                volume-sent: (get volume-sent receiver-stats),
                volume-received: (+ (get volume-received receiver-stats) amount),
                avg-sent: (get avg-sent receiver-stats),
                avg-received: (/ (+ (get volume-received receiver-stats) amount) 
                              (+ (get payments-received receiver-stats) u1))
            }
        )
    )
)

(define-private (update-daily-stats (amount uint) (category uint))
    (let (
        (today (get-current-date))
        (current-stats (default-to 
            { payment-count: u0, total-volume: u0, avg-payment: u0, categories: (list u0 u0 u0 u0 u0) }
            (map-get? daily-stats { date: today })
        ))
    )
        (map-set daily-stats
            { date: today }
            {
                payment-count: (+ (get payment-count current-stats) u1),
                total-volume: (+ (get total-volume current-stats) amount),
                avg-payment: (/ (+ (get total-volume current-stats) amount) 
                             (+ (get payment-count current-stats) u1)),
                categories: (get categories current-stats) ;; Simplified for now
            }
        )
    )
)

;; Public functions

(define-public (record-payment (amount uint) (category uint) (receiver principal))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-valid-category category) ERR_INVALID_CATEGORY)
        
        (let (
            (payment-id (var-get next-payment-id))
        )
            ;; Record the payment
            (map-set payment-records
                { payment-id: payment-id }
                {
                    amount: amount,
                    category: category,
                    timestamp: block-height,
                    payer: tx-sender,
                    receiver: receiver,
                    completed: true
                }
            )
            
            ;; Update global statistics
            (var-set total-payments-processed (+ (var-get total-payments-processed) u1))
            (var-set total-volume (+ (var-get total-volume) amount))
            (var-set next-payment-id (+ payment-id u1))
            
            ;; Update category statistics
            (update-category-stats category amount)
            
            ;; Update user statistics
            (update-user-stats tx-sender receiver amount)
            
            ;; Update daily statistics
            (update-daily-stats amount category)
            
            (ok payment-id)
        )
    )
)

;; Read-only functions for analytics

(define-read-only (get-total-stats)
    {
        total-payments: (var-get total-payments-processed),
        total-volume: (var-get total-volume),
        avg-payment: (if (> (var-get total-payments-processed) u0)
                        (/ (var-get total-volume) (var-get total-payments-processed))
                        u0)
    }
)

(define-read-only (get-category-stats (category uint))
    (if (is-valid-category category)
        (ok (map-get? category-stats { category: category }))
        ERR_INVALID_CATEGORY
    )
)

(define-read-only (get-user-stats (user principal))
    (ok (map-get? user-payment-stats { user: user }))
)

(define-read-only (get-daily-stats (date uint))
    (ok (map-get? daily-stats { date: date }))
)

(define-read-only (get-payment-record (payment-id uint))
    (ok (map-get? payment-records { payment-id: payment-id }))
)

(define-read-only (get-current-payment-id)
    (var-get next-payment-id)
)

;; Analytics insights

(define-read-only (get-top-category)
    ;; Returns category with highest volume
    (let (
        (cat1-stats (default-to { total-volume: u0 } 
                    (map-get? category-stats { category: CATEGORY_WEB_DEV })))
        (cat2-stats (default-to { total-volume: u0 } 
                    (map-get? category-stats { category: CATEGORY_DESIGN })))
        (cat3-stats (default-to { total-volume: u0 } 
                    (map-get? category-stats { category: CATEGORY_WRITING })))
        (cat4-stats (default-to { total-volume: u0 } 
                    (map-get? category-stats { category: CATEGORY_MARKETING })))
        (cat5-stats (default-to { total-volume: u0 } 
                    (map-get? category-stats { category: CATEGORY_OTHER })))
    )
        (if (>= (get total-volume cat1-stats) (get total-volume cat2-stats))
            (if (>= (get total-volume cat1-stats) (get total-volume cat3-stats))
                (if (>= (get total-volume cat1-stats) (get total-volume cat4-stats))
                    (if (>= (get total-volume cat1-stats) (get total-volume cat5-stats))
                        CATEGORY_WEB_DEV
                        CATEGORY_OTHER)
                    CATEGORY_MARKETING)
                CATEGORY_WRITING)
            CATEGORY_DESIGN)
    )
)

(define-read-only (calculate-growth-rate (days-back uint))
    ;; Simple growth rate calculation
    (let (
        (current-date (get-current-date))
        (past-date (- current-date days-back))
        (current-stats (map-get? daily-stats { date: current-date }))
        (past-stats (map-get? daily-stats { date: past-date }))
    )
        (match current-stats
            current-data
            (match past-stats
                past-data
                (if (> (get total-volume past-data) u0)
                    (ok (/ (* (- (get total-volume current-data) (get total-volume past-data)) u100)
                         (get total-volume past-data)))
                    (ok u0))
                (ok u0))
            (ok u0))
    )
)

;; Admin functions

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)