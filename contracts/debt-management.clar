;; Debt Management Contract
;; Coordinates debt reduction strategies and payment plans

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_INSUFFICIENT_STAKE (err u403))
(define-constant ERR_USER_NOT_FOUND (err u404))
(define-constant ERR_DEBT_NOT_FOUND (err u405))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var min-stake-amount uint u800)
(define-data-var total-debt-plans uint u0)

;; Data Maps
(define-map user-stakes principal uint)
(define-map debt-profiles principal {
    total-debt: uint,
    monthly-income: uint,
    available-payment: uint,
    debt-to-income-ratio: uint,
    last-updated: uint
})

(define-map debt-items principal (list 10 {
    debt-type: (string-ascii 20),
    balance: uint,
    interest-rate: uint,
    minimum-payment: uint,
    priority-score: uint
}))

(define-map payment-strategies principal {
    strategy-type: (string-ascii 20),
    total-monthly-payment: uint,
    payoff-timeline: uint,
    total-interest-saved: uint,
    next-payment-target: (string-ascii 20),
    last-strategy-update: uint
})

(define-map debt-progress principal {
    original-debt: uint,
    current-debt: uint,
    total-paid: uint,
    months-remaining: uint,
    on-track: bool,
    last-progress-update: uint
})

;; Public Functions

;; Register user and stake tokens
(define-public (register-debtor (stake-amount uint))
    (let ((current-stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (>= stake-amount (var-get min-stake-amount)) ERR_INSUFFICIENT_STAKE)
        (map-set user-stakes tx-sender (+ current-stake stake-amount))
        (if (is-eq current-stake u0)
            (var-set total-debt-plans (+ (var-get total-debt-plans) u1))
            true)
        (ok true)))

;; Update debt profile
(define-public (update-debt-profile (total-debt uint) (monthly-income uint) (available-payment uint))
    (let ((stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (> monthly-income u0) ERR_INVALID_AMOUNT)

        (let ((debt-ratio (if (> monthly-income u0) (/ (* total-debt u100) monthly-income) u0)))
            (map-set debt-profiles tx-sender {
                total-debt: total-debt,
                monthly-income: monthly-income,
                available-payment: available-payment,
                debt-to-income-ratio: debt-ratio,
                last-updated: block-height
            })
            (ok true))))

;; Add debt item
(define-public (add-debt-item (debt-type (string-ascii 20)) (balance uint)
                             (interest-rate uint) (minimum-payment uint))
    (let ((stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (> balance u0) ERR_INVALID_AMOUNT)

        (let (
            (current-debts (default-to (list) (map-get? debt-items tx-sender)))
            (priority-score (+ interest-rate (/ balance u1000)))
            (new-debt {
                debt-type: debt-type,
                balance: balance,
                interest-rate: interest-rate,
                minimum-payment: minimum-payment,
                priority-score: priority-score
            })
        )
            (map-set debt-items tx-sender (unwrap-panic (as-max-len? (append current-debts new-debt) u10)))
            (ok true))))

;; Generate debt reduction strategy
(define-public (generate-strategy (strategy-type (string-ascii 20)))
    (let (
        (stake (default-to u0 (map-get? user-stakes tx-sender)))
        (profile (map-get? debt-profiles tx-sender))
        (debts (map-get? debt-items tx-sender))
    )
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (is-some profile) ERR_USER_NOT_FOUND)

        (let (
            (total-debt (get total-debt (unwrap-panic profile)))
            (available-payment (get available-payment (unwrap-panic profile)))
            (estimated-timeline (if (> available-payment u0) (/ total-debt available-payment) u0))
            (interest-saved (/ total-debt u10))
        )
            (map-set payment-strategies tx-sender {
                strategy-type: strategy-type,
                total-monthly-payment: available-payment,
                payoff-timeline: estimated-timeline,
                total-interest-saved: interest-saved,
                next-payment-target: "highest-interest",
                last-strategy-update: block-height
            })
            (ok {
                monthly-payment: available-payment,
                timeline: estimated-timeline,
                interest-saved: interest-saved
            }))))

;; Update debt progress
(define-public (update-progress (current-debt uint) (total-paid uint))
    (let (
        (stake (default-to u0 (map-get? user-stakes tx-sender)))
        (profile (map-get? debt-profiles tx-sender))
    )
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (is-some profile) ERR_USER_NOT_FOUND)

        (let (
            (original-debt (get total-debt (unwrap-panic profile)))
            (available-payment (get available-payment (unwrap-panic profile)))
            (months-remaining (if (> available-payment u0) (/ current-debt available-payment) u0))
            (on-track (< current-debt (- original-debt (* total-paid u1))))
        )
            (map-set debt-progress tx-sender {
                original-debt: original-debt,
                current-debt: current-debt,
                total-paid: total-paid,
                months-remaining: months-remaining,
                on-track: on-track,
                last-progress-update: block-height
            })
            (ok true))))

;; Withdraw stake
(define-public (withdraw-stake (amount uint))
    (let ((current-stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (>= current-stake amount) ERR_INSUFFICIENT_STAKE)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (map-set user-stakes tx-sender (- current-stake amount))
        (ok true)))

;; Read-only functions

(define-read-only (get-user-stake (user principal))
    (default-to u0 (map-get? user-stakes user)))

(define-read-only (get-debt-profile (user principal))
    (map-get? debt-profiles user))

(define-read-only (get-debt-items (user principal))
    (map-get? debt-items user))

(define-read-only (get-payment-strategy (user principal))
    (map-get? payment-strategies user))

(define-read-only (get-debt-progress (user principal))
    (map-get? debt-progress user))

(define-read-only (get-contract-stats)
    {
        total-plans: (var-get total-debt-plans),
        min-stake: (var-get min-stake-amount),
        active: (var-get contract-active)
    })

;; Admin functions

(define-public (set-min-stake (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set min-stake-amount new-amount)
        (ok true)))

(define-public (toggle-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-active (not (var-get contract-active)))
        (ok (var-get contract-active))))
