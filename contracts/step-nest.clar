;; step-nest.clar
;; StepNest Walking Tracker Core Contract
;;
;; This contract manages user profiles, walking/hiking activity tracking, route sharing,
;; and social features for the StepNest platform. It allows users to create profiles,
;; record verified activities, share routes, and engage in community challenges.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant ERR-USER-ALREADY-EXISTS (err u102))
(define-constant ERR-ROUTE-NOT-FOUND (err u103))
(define-constant ERR-ACTIVITY-NOT-FOUND (err u104))
(define-constant ERR-CHALLENGE-NOT-FOUND (err u105))
(define-constant ERR-INVALID-ROUTE-DATA (err u106))
(define-constant ERR-INVALID-ACTIVITY-DATA (err u107))
(define-constant ERR-ALREADY-FOLLOWING (err u108))
(define-constant ERR-NOT-FOLLOWING (err u109))
(define-constant ERR-CANNOT-FOLLOW-SELF (err u110))
(define-constant ERR-ALREADY-RATED (err u111))
(define-constant ERR-INVALID-RATING (err u112))
(define-constant ERR-CHALLENGE-CLOSED (err u113))
(define-constant ERR-ALREADY-JOINED-CHALLENGE (err u114))

;; Data maps

;; User profiles
(define-map users
  { user-id: principal }
  {
    username: (string-ascii 30),
    bio: (string-utf8 500),
    join-date: uint,
    total-distance: uint,  ;; in meters
    total-activities: uint,
    reputation-score: uint,
    profile-privacy: (string-ascii 10),  ;; "public", "followers", "private"
    achievements: (list 20 (string-ascii 30))
  }
)

;; Walking/hiking activities
(define-map activities
  { activity-id: uint }
  {
    user-id: principal,
    route-id: (optional uint),
    start-time: uint,
    end-time: uint,
    distance: uint,  ;; in meters
    elevation-gain: uint,  ;; in meters
    steps: uint,
    route-data: (string-utf8 10000),  ;; JSON string with GPS coordinates
    privacy: (string-ascii 10),  ;; "public", "followers", "private"
    verified: bool
  }
)

;; Shared routes
(define-map routes
  { route-id: uint }
  {
    creator: principal,
    name: (string-utf8 100),
    description: (string-utf8 1000),
    location: (string-utf8 100),
    distance: uint,  ;; in meters
    elevation-gain: uint,  ;; in meters
    difficulty: uint,  ;; 1-5 scale
    route-data: (string-utf8 10000),  ;; JSON string with GPS coordinates
    creation-date: uint,
    privacy: (string-ascii 10),  ;; "public", "followers", "private"
    tags: (list 10 (string-ascii 20))
  }
)

;; Route ratings
(define-map route-ratings
  { route-id: uint, user-id: principal }
  {
    rating: uint,  ;; 1-5 scale
    comment: (string-utf8 500),
    timestamp: uint
  }
)

;; Social follows
(define-map follows
  { follower: principal, following: principal }
  {
    timestamp: uint
  }
)

;; Challenges
(define-map challenges
  { challenge-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 1000),
    creator: principal,
    start-date: uint,
    end-date: uint,
    goal-type: (string-ascii 20),  ;; "distance", "activities", "elevation"
    goal-value: uint,
    participants: (list 100 principal),
    is-active: bool
  }
)

;; Challenge completions
(define-map challenge-completions
  { challenge-id: uint, user-id: principal }
  {
    completed: bool,
    progress: uint,
    completion-date: (optional uint)
  }
)

;; Counters for IDs
(define-data-var activity-id-counter uint u0)
(define-data-var route-id-counter uint u0)
(define-data-var challenge-id-counter uint u0)

;; Private functions

;; Check if user exists
(define-private (user-exists (user-id principal))
  (is-some (map-get? users { user-id: user-id }))
)

;; Verify route ownership
(define-private (is-route-owner (route-id uint) (user-id principal))
  (match (map-get? routes { route-id: route-id })
    route (is-eq (get creator route) user-id)
    false
  )
)

;; Verify activity ownership
(define-private (is-activity-owner (activity-id uint) (user-id principal))
  (match (map-get? activities { activity-id: activity-id })
    activity (is-eq (get user-id activity) user-id)
    false
  )
)

;; Verify challenge ownership
(define-private (is-challenge-owner (challenge-id uint) (user-id principal))
  (match (map-get? challenges { challenge-id: challenge-id })
    challenge (is-eq (get creator challenge) user-id)
    false
  )
)

;; Increment user's reputation score
(define-private (increment-reputation (user-id principal) (points uint))
  (match (map-get? users { user-id: user-id })
    user (map-set users 
          { user-id: user-id }
          (merge user { reputation-score: (+ (get reputation-score user) points) }))
    false
  )
)

;; Update user's total distance
(define-private (add-distance (user-id principal) (distance uint))
  (match (map-get? users { user-id: user-id })
    user (map-set users 
          { user-id: user-id }
          (merge user { 
            total-distance: (+ (get total-distance user) distance),
            total-activities: (+ (get total-activities user) u1)
          }))
    false
  )
)

;; Check achievement milestones and update user profile
(define-private (check-achievements (user-id principal))
  (match (map-get? users { user-id: user-id })
    user 
    (let ((current-achievements (get achievements user))
          (total-distance (get total-distance user))
          (total-activities (get total-activities user))
          (new-achievements (list)))
      
      ;; Check distance-based achievements
      (let ((distance-achievements 
             (cond
              ((>= total-distance u100000) (append new-achievements "100km-walker"))
              ((>= total-distance u50000) (append new-achievements "50km-walker"))
              ((>= total-distance u10000) (append new-achievements "10km-walker"))
              (true new-achievements))))
        
        ;; Check activity-based achievements
        (let ((activity-achievements 
               (cond
                ((>= total-activities u100) (append distance-achievements "century-hiker"))
                ((>= total-activities u50) (append distance-achievements "50-hikes-completed"))
                ((>= total-activities u10) (append distance-achievements "10-hikes-completed"))
                (true distance-achievements))))
          
          ;; Update user achievements if new ones were earned
          (if (> (len activity-achievements) u0)
            (map-set users 
              { user-id: user-id }
              (merge user { 
                achievements: (filter not-in-list current-achievements activity-achievements)
              }))
            true
          )
        )
      )
    )
    false
  )
)

;; Helper to check if item is not in a list
(define-private (not-in-list (item (string-ascii 30)) (list-to-check (list 20 (string-ascii 30))))
  (is-none (index-of list-to-check item))
)

;; Read-only functions

;; Get user profile
(define-read-only (get-user-profile (user-id principal))
  (map-get? users { user-id: user-id })
)

;; Get activity details
(define-read-only (get-activity (activity-id uint))
  (map-get? activities { activity-id: activity-id })
)

;; Get route details
(define-read-only (get-route (route-id uint))
  (map-get? routes { route-id: route-id })
)

;; Get route rating by user
(define-read-only (get-user-route-rating (route-id uint) (user-id principal))
  (map-get? route-ratings { route-id: route-id, user-id: user-id })
)

;; Check if user is following another user
(define-read-only (is-following (follower principal) (following principal))
  (is-some (map-get? follows { follower: follower, following: following }))
)

;; Get challenge details
(define-read-only (get-challenge (challenge-id uint))
  (map-get? challenges { challenge-id: challenge-id })
)

;; Get user's challenge progress
(define-read-only (get-challenge-progress (challenge-id uint) (user-id principal))
  (map-get? challenge-completions { challenge-id: challenge-id, user-id: user-id })
)

;; Public functions

;; Register a new user
(define-public (register-user (username (string-ascii 30)) (bio (string-utf8 500)) (privacy (string-ascii 10)))
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      ERR-USER-ALREADY-EXISTS
      (begin
        (map-set users
          { user-id: user-id }
          {
            username: username,
            bio: bio,
            join-date: block-height,
            total-distance: u0,
            total-activities: u0,
            reputation-score: u0,
            profile-privacy: privacy,
            achievements: (list)
          }
        )
        (ok true)
      )
    )
  )
)

;; Update user profile
(define-public (update-profile (username (string-ascii 30)) (bio (string-utf8 500)) (privacy (string-ascii 10)))
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      (match (map-get? users { user-id: user-id })
        user 
        (begin
          (map-set users
            { user-id: user-id }
            (merge user {
              username: username,
              bio: bio,
              profile-privacy: privacy
            })
          )
          (ok true)
        )
        ERR-USER-NOT-FOUND
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Record a new activity
(define-public (record-activity 
  (route-id (optional uint))
  (start-time uint)
  (end-time uint)
  (distance uint)
  (elevation-gain uint)
  (steps uint)
  (route-data (string-utf8 10000))
  (privacy (string-ascii 10)))
  
  (let ((user-id tx-sender)
        (activity-id (var-get activity-id-counter)))
    (if (user-exists user-id)
      (if (>= start-time end-time)
        ERR-INVALID-ACTIVITY-DATA
        (begin
          ;; Create new activity
          (map-set activities
            { activity-id: activity-id }
            {
              user-id: user-id,
              route-id: route-id,
              start-time: start-time,
              end-time: end-time,
              distance: distance,
              elevation-gain: elevation-gain,
              steps: steps,
              route-data: route-data,
              privacy: privacy,
              verified: true  ;; Auto-verified for now, could integrate verification logic later
            }
          )
          
          ;; Update user stats
          (add-distance user-id distance)
          
          ;; Increment reputation
          (increment-reputation user-id u1)
          
          ;; Check for new achievements
          (check-achievements user-id)
          
          ;; Increment activity counter
          (var-set activity-id-counter (+ activity-id u1))
          
          ;; Check and update challenge progress
          ;; (For simplicity, this part is omitted but would be implemented here)
          
          (ok activity-id)
        )
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Create a new route
(define-public (create-route
  (name (string-utf8 100))
  (description (string-utf8 1000))
  (location (string-utf8 100))
  (distance uint)
  (elevation-gain uint)
  (difficulty uint)
  (route-data (string-utf8 10000))
  (privacy (string-ascii 10))
  (tags (list 10 (string-ascii 20))))
  
  (let ((user-id tx-sender)
        (route-id (var-get route-id-counter)))
    (if (user-exists user-id)
      (if (and (> distance u0) (> (len route-data) u10) (<= difficulty u5) (>= difficulty u1))
        (begin
          ;; Create new route
          (map-set routes
            { route-id: route-id }
            {
              creator: user-id,
              name: name,
              description: description,
              location: location,
              distance: distance,
              elevation-gain: elevation-gain,
              difficulty: difficulty,
              route-data: route-data,
              creation-date: block-height,
              privacy: privacy,
              tags: tags
            }
          )
          
          ;; Increment reputation for creating a route
          (increment-reputation user-id u5)
          
          ;; Increment route counter
          (var-set route-id-counter (+ route-id u1))
          
          (ok route-id)
        )
        ERR-INVALID-ROUTE-DATA
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Rate a route
(define-public (rate-route (route-id uint) (rating uint) (comment (string-utf8 500)))
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      (if (is-some (map-get? routes { route-id: route-id }))
        (if (and (>= rating u1) (<= rating u5))
          (if (is-some (map-get? route-ratings { route-id: route-id, user-id: user-id }))
            ERR-ALREADY-RATED
            (begin
              (map-set route-ratings
                { route-id: route-id, user-id: user-id }
                {
                  rating: rating,
                  comment: comment,
                  timestamp: block-height
                }
              )
              
              ;; Increment reputation for rating a route
              (increment-reputation user-id u1)
              
              (ok true)
            )
          )
          ERR-INVALID-RATING
        )
        ERR-ROUTE-NOT-FOUND
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Follow a user
(define-public (follow-user (user-to-follow principal))
  (let ((follower tx-sender))
    (if (is-eq follower user-to-follow)
      ERR-CANNOT-FOLLOW-SELF
      (if (and (user-exists follower) (user-exists user-to-follow))
        (if (is-following follower user-to-follow)
          ERR-ALREADY-FOLLOWING
          (begin
            (map-set follows
              { follower: follower, following: user-to-follow }
              { timestamp: block-height }
            )
            (ok true)
          )
        )
        ERR-USER-NOT-FOUND
      )
    )
  )
)

;; Unfollow a user
(define-public (unfollow-user (user-to-unfollow principal))
  (let ((follower tx-sender))
    (if (is-following follower user-to-unfollow)
      (begin
        (map-delete follows { follower: follower, following: user-to-unfollow })
        (ok true)
      )
      ERR-NOT-FOLLOWING
    )
  )
)

;; Create a challenge
(define-public (create-challenge 
  (name (string-utf8 100))
  (description (string-utf8 1000))
  (start-date uint)
  (end-date uint)
  (goal-type (string-ascii 20))
  (goal-value uint))
  
  (let ((user-id tx-sender)
        (challenge-id (var-get challenge-id-counter)))
    (if (user-exists user-id)
      (if (> end-date start-date)
        (begin
          (map-set challenges
            { challenge-id: challenge-id }
            {
              name: name,
              description: description,
              creator: user-id,
              start-date: start-date,
              end-date: end-date,
              goal-type: goal-type,
              goal-value: goal-value,
              participants: (list user-id),
              is-active: true
            }
          )
          
          ;; Initialize creator as first participant
          (map-set challenge-completions
            { challenge-id: challenge-id, user-id: user-id }
            {
              completed: false,
              progress: u0,
              completion-date: none
            }
          )
          
          ;; Increment reputation for creating a challenge
          (increment-reputation user-id u10)
          
          ;; Increment challenge counter
          (var-set challenge-id-counter (+ challenge-id u1))
          
          (ok challenge-id)
        )
        ERR-INVALID-ROUTE-DATA
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Join a challenge
(define-public (join-challenge (challenge-id uint))
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      (match (map-get? challenges { challenge-id: challenge-id })
        challenge
        (if (get is-active challenge)
          (if (is-some (find (lambda (p) (is-eq p user-id)) (get participants challenge)))
            ERR-ALREADY-JOINED-CHALLENGE
            (begin
              ;; Add user to challenge participants
              (map-set challenges
                { challenge-id: challenge-id }
                (merge challenge {
                  participants: (append (get participants challenge) user-id)
                })
              )
              
              ;; Initialize user's progress
              (map-set challenge-completions
                { challenge-id: challenge-id, user-id: user-id }
                {
                  completed: false,
                  progress: u0,
                  completion-date: none
                }
              )
              
              (ok true)
            )
          )
          ERR-CHALLENGE-CLOSED
        )
        ERR-CHALLENGE-NOT-FOUND
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Update challenge progress (simplified - in a real implementation, this would
;; be updated automatically when activities are recorded)
(define-public (update-challenge-progress (challenge-id uint) (progress uint))
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      (match (map-get? challenges { challenge-id: challenge-id })
        challenge
        (match (map-get? challenge-completions { challenge-id: challenge-id, user-id: user-id })
          completion
          (begin
            (map-set challenge-completions
              { challenge-id: challenge-id, user-id: user-id }
              {
                completed: (>= progress (get goal-value challenge)),
                progress: progress,
                completion-date: (if (>= progress (get goal-value challenge))
                                   (some block-height)
                                   (get completion-date completion))
              }
            )
            
            ;; Award reputation if challenge completed
            (if (and (>= progress (get goal-value challenge)) 
                    (is-none (get completion-date completion)))
              (increment-reputation user-id u20)
              true
            )
            
            (ok true)
          )
          ERR-CHALLENGE-NOT-FOUND
        )
        ERR-CHALLENGE-NOT-FOUND
      )
      ERR-USER-NOT-FOUND
    )
  )
)