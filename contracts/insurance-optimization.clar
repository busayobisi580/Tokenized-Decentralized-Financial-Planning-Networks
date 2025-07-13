;; Insurance Optimization Contract
;; Reviews coverage needs and cost-effective options

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_INSUFFICIENT_STAKE (err u403))
(define-constant ERR_USER_NOT_FOUND (err u404))
(define-constant ERR_INVALID_COVERAGE (err u405))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var min-stake-amount uint u600)
(define-data-var total-policies uint u0)

;; Data Maps
(define-map user-stakes principal uint)
(define-map insurance-profiles principal {
    age: uint,
    dependents: uint,
    annual-income: uint,
    assets-value: uint,
    health-status: uint,
    last-updated: uint
})

(define-map current-policies principal (list 5 {
    policy-type: (string-ascii 20),
    coverage-amount: uint,
    annual-premium: uint,
    deductible: uint,
    provider: (string-ascii 30)
}))

(define-map coverage-recommendations principal {
    life-insurance-needed: uint,
    health-insurance-rec: uint,
    disability-insurance-rec: uint,
    property-insurance-rec: uint,
    total-premium-budget: uint,
    potential-savings: uint,
    last-recommendation: uint
})

(define-map policy-performance principal {
    total-premiums-paid: uint,
    claims-filed: uint,
    claims-paid: uint,
    coverage-utilization: uint,
    satisfaction-score: uint,
    last-performance-update: uint
})

;; Public Functions

;; Register user and stake tokens
(define-public (register-policyholder (stake-amount uint))
    (let ((current-stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (>= stake-amount (var-get min-stake-amount)) ERR_INSUFFICIENT_STAKE)
        (map-set user-stakes tx-sender (+ current-stake stake-amount))
        (if (is-eq current-stake u0)
            (var-set total-policies (+ (var-get total-policies) u1))
            true)
        (ok true)))

;; Update insurance profile
(define-public (update-insurance-profile (age uint) (dependents uint) (annual-income uint)
                                        (assets-value uint) (health-status uint))
    (let ((stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (> annual-income u0) ERR_INVALID_AMOUNT)
        (asserts! (and (>= health-status u1) (<= health-status u10)) ERR_INVALID_COVERAGE)
        (map-set insurance-profiles tx-sender {
            age: age,
            dependents: dependents,
            annual-income: annual-income,
            assets-value: assets-value,
            health-status: health-status,
            last-updated: block-height
        })
        (ok true)))

;; Add current policy
(define-public (add-policy (policy-type (string-ascii 20)) (coverage-amount uint)
                          (annual-premium uint) (deductible uint) (provider (string-ascii 30)))
    (let ((stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (> coverage-amount u0) ERR_INVALID_AMOUNT)

        (let (
            (current-policies-list (default-to (list) (map-get? current-policies tx-sender)))
            (new-policy {
                policy-type: policy-type,
                coverage-amount: coverage-amount,
                annual-premium: annual-premium,
                deductible: deductible,
                provider: provider
            })
        )
            (map-set current-policies tx-sender
                    (unwrap-panic (as-max-len? (append current-policies-list new-policy) u5)))
            (ok true))))

;; Generate coverage recommendations
(define-public (generate-coverage-recommendations)
    (let (
        (stake (default-to u0 (map-get? user-stakes tx-sender)))
        (profile (map-get? insurance-profiles tx-sender))
    )
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (is-some profile) ERR_USER_NOT_FOUND)

        (let (
            (annual-income (get annual-income (unwrap-panic profile)))
            (dependents (get dependents (unwrap-panic profile)))
            (assets-value (get assets-value (unwrap-panic profile)))
            (life-insurance-needed (* annual-income (+ u10 dependents)))
            (health-insurance-rec (/ annual-income u20))
            (disability-insurance-rec (/ (* annual-income u60) u100))
            (property-insurance-rec (/ assets-value u100))
            (total-budget (/ annual-income u10))
            (potential-savings (/ total-budget u20))
        )
            (map-set coverage-recommendations tx-sender {
                life-insurance-needed: life-insurance-needed,
                health-insurance-rec: health-insurance-rec,
                disability-insurance-rec: disability-insurance-rec,
                property-insurance-rec: property-insurance-rec,
                total-premium-budget: total-budget,
                potential-savings: potential-savings,
                last-recommendation: block-height
            })
            (ok {
                life-coverage: life-insurance-needed,
                health-coverage: health-insurance-rec,
                total-budget: total-budget,
                savings: potential-savings
            }))))

;; Update policy performance
(define-public (update-performance (total-premiums-paid uint) (claims-filed uint)
                                  (claims-paid uint) (satisfaction-score uint))
    (let ((stake (default-to u0 (map-get? user-stakes tx-sender))))
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (> stake u0) ERR_INSUFFICIENT_STAKE)
        (asserts! (and (>= satisfaction-score u1) (<= satisfaction-score u10)) ERR_INVALID_COVERAGE)

        (let (
            (utilization (if (> total-premiums-paid u0)
                           (/ (* claims-paid u100) total-premiums-paid)
                           u0))
        )
            (map-set policy-performance tx-sender {
                total-premiums-paid: total-premiums-paid,
                claims-filed: claims-filed,
                claims-paid: claims-paid,
                coverage-utilization: utilization,
                satisfaction-score: satisfaction-score,
                last-performance-update: block-height
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

(define-read-only (get-insurance-profile (user principal))
    (map-get? insurance-profiles user))

(define-read-only (get-current-policies (user principal))
    (map-get? current-policies user))

(define-read-only (get-coverage-recommendations (user principal))
    (map-get? coverage-recommendations user))

(define-read-only (get-policy-performance (user principal))
    (map-get? policy-performance user))

(define-read-only (get-contract-stats)
    {
        total-policies: (var-get total-policies),
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
