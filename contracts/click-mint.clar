;; Define NFT token
(define-non-fungible-token campaign-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-campaign-expired (err u104))
(define-constant err-campaign-paused (err u105))
(define-constant err-rate-limited (err u106))

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
    status: (string-utf8 10),
    paused: bool,
    last-update: uint
  }
)

;; Campaign counter
(define-data-var campaign-counter uint u0)

;; Events
(define-public (print-campaign-event 
  (event-type (string-utf8 12)) 
  (campaign-id uint)
  (data (optional (string-utf8 64)))
)
  (print { 
    event-type: event-type, 
    campaign-id: campaign-id, 
    sender: tx-sender,
    data: data 
  })
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
    (asserts! (is-valid-url url) (err err-invalid-params))
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
        status: "active",
        paused: false,
        last-update: block-height
      }
    )
    (var-set campaign-counter campaign-id)
    (try! (print-campaign-event "create" campaign-id none))
    (ok campaign-id)
  )
)

;; Pause campaign
(define-public (pause-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (asserts! (is-eq tx-sender (get owner campaign)) (err err-unauthorized))
    (asserts! (not (get paused campaign)) (err err-campaign-paused))
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { paused: true })
    ))
  )
)

;; Resume campaign
(define-public (resume-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (asserts! (is-eq tx-sender (get owner campaign)) (err err-unauthorized))
    (asserts! (get paused campaign) (err err-invalid-params))
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { paused: false })
    ))
  )
)

;; Check if campaign is active
(define-read-only (is-campaign-active (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (ok (and 
      (< block-height (get end-time campaign))
      (not (get paused campaign))
    ))
  )
)

;; URL validation helper
(define-private (is-valid-url (url (string-utf8 256)))
  (and
    (> (len url) u4)
    (is-eq (slice url u0 u4) "http")
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
    (
      (campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found)))
      (last-update (get last-update campaign))
    )
    (asserts! (is-eq tx-sender (get owner campaign)) (err err-unauthorized))
    (asserts! (unwrap! (is-campaign-active campaign-id) (err err-not-found)) (err err-campaign-expired))
    (asserts! (>= new-clicks new-conversions) (err err-invalid-params))
    (asserts! (>= new-impressions new-clicks) (err err-invalid-params))
    (asserts! (>= (- block-height last-update) u10) (err err-rate-limited))
    
    (try! (print-campaign-event "metrics-update" campaign-id none))
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign
        {
          impressions: new-impressions,
          clicks: new-clicks,
          conversions: new-conversions,
          last-update: block-height
        }
      )
    ))
  )
)

;; [Rest of the original functions remain unchanged...]
