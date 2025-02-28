;; Define NFT token
(define-non-fungible-token campaign-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-campaign-expired (err u104))

;; Campaign data structure
(define-map campaigns
  { campaign-id: uint }
  {
    owner: principal,
    name: (string-utf8 64),
    url: (string-utf8 256),
    impressions: uint,
    clicks: uint,
    conversions: uint,
    start-time: uint,
    end-time: uint,
    status: (string-utf8 10)
  }
)

;; Campaign counter
(define-data-var campaign-counter uint u0)

;; Events
(define-public (print-campaign-event (event-type (string-utf8 12)) (campaign-id uint))
  (print { event-type: event-type, campaign-id: campaign-id, sender: tx-sender })
  (ok true)
)

;; Create new campaign
(define-public (create-campaign 
  (name (string-utf8 64))
  (url (string-utf8 256))
  (duration uint)
)
  (let
    (
      (campaign-id (+ (var-get campaign-counter) u1))
      (start-time block-height)
      (end-time (+ block-height duration))
    )
    ;; Validate parameters
    (asserts! (> duration u0) (err err-invalid-params))
    (try! (nft-mint? campaign-nft campaign-id tx-sender))
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        owner: tx-sender,
        name: name,
        url: url,
        impressions: u0,
        clicks: u0,
        conversions: u0,
        start-time: start-time,
        end-time: end-time,
        status: "active"
      }
    )
    (var-set campaign-counter campaign-id)
    (try! (print-campaign-event "create" campaign-id))
    (ok campaign-id)
  )
)

;; Check if campaign is active
(define-read-only (is-campaign-active (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (ok (< block-height (get end-time campaign)))
  )
)

;; Update campaign metrics
(define-public (update-metrics
  (campaign-id uint)
  (new-impressions uint)
  (new-clicks uint) 
  (new-conversions uint)
)
  (let
    ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (asserts! (is-eq tx-sender (get owner campaign)) (err err-unauthorized))
    (asserts! (unwrap! (is-campaign-active campaign-id) (err err-not-found)) (err err-campaign-expired))
    (asserts! (>= new-clicks new-conversions) (err err-invalid-params))
    (asserts! (>= new-impressions new-clicks) (err err-invalid-params))
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign
        {
          impressions: new-impressions,
          clicks: new-clicks,
          conversions: new-conversions
        }
      )
    ))
  )
)

;; Get campaign details
(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns {campaign-id: campaign-id})
)

;; Get campaign metrics
(define-read-only (get-campaign-metrics (campaign-id uint))
  (match (map-get? campaigns {campaign-id: campaign-id})
    campaign (ok {
      impressions: (get impressions campaign),
      clicks: (get clicks campaign),
      conversions: (get conversions campaign)
    })
    (err err-not-found)
  )
)

;; Transfer campaign ownership
(define-public (transfer-campaign
  (campaign-id uint)
  (recipient principal)
)
  (let
    ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (asserts! (is-eq tx-sender (get owner campaign)) (err err-unauthorized))
    (try! (nft-transfer? campaign-nft campaign-id tx-sender recipient))
    (try! (print-campaign-event "transfer" campaign-id))
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign {owner: recipient})
    ))
  )
)
