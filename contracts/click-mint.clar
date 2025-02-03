;; Define NFT token
(define-non-fungible-token campaign-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))

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
    end-time: uint
  }
)

;; Campaign counter
(define-data-var campaign-counter uint u0)

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
        end-time: end-time
      }
    )
    (var-set campaign-counter campaign-id)
    (ok campaign-id)
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

;; Transfer campaign ownership
(define-public (transfer-campaign
  (campaign-id uint)
  (recipient principal)
)
  (let
    ((campaign (unwrap! (map-get? campaigns {campaign-id: campaign-id}) (err err-not-found))))
    (asserts! (is-eq tx-sender (get owner campaign)) (err err-unauthorized))
    (try! (nft-transfer? campaign-nft campaign-id tx-sender recipient))
    (ok (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign {owner: recipient})
    ))
  )
)
