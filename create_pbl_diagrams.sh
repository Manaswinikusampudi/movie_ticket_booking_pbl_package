#!/usr/bin/env bash
set -e
OUT=/home/ubuntu/movie_booking_pbl_diagrams
mkdir -p "$OUT"
cat > "$OUT/01_hld_architecture.mmd" <<'EOF'
flowchart LR
  U[Customer Web / Mobile App] --> G[API Gateway]
  A[Admin / Theatre Portal] --> G
  G --> AUTH[Auth & User Service]
  G --> CAT[Movie & Theatre Catalog Service]
  G --> SHOW[Showtime Service]
  G --> INV[Seat Inventory Service]
  G --> BOOK[Booking Service]
  G --> PAY[Payment Service]
  G --> NOTIF[Notification Service]
  CAT --> DB[(PostgreSQL)]
  SHOW --> DB
  INV --> REDIS[(Redis Seat Locks)]
  INV --> DB
  BOOK --> DB
  PAY --> PG[Payment Gateway]
  BOOK --> NOTIF
  NOTIF --> Q[Message Queue]
  Q --> EMAIL[Email/SMS Provider]
  G --> OBS[Logging / Metrics / Tracing]
EOF
cat > "$OUT/02_module_decomposition.mmd" <<'EOF'
flowchart TB
  SYS[Movie Ticket Booking System]
  SYS --> CUST[Customer Module]
  SYS --> ADMIN[Administration Module]
  SYS --> CORE[Booking Core]
  SYS --> PLATFORM[Platform Services]
  CUST --> SEARCH[Search Movies & Theatres]
  CUST --> SHOWB[Browse Shows]
  CUST --> SEATB[Select Seats]
  CUST --> CHECK[Checkout & Payment]
  CUST --> TICK[View / Cancel Ticket]
  ADMIN --> MOV[Manage Movies]
  ADMIN --> THEAT[Manage Theatres & Screens]
  ADMIN --> SCH[Manage Shows & Pricing]
  ADMIN --> REP[Reports]
  CORE --> AVAIL[Availability]
  CORE --> LOCK[Seat Locking]
  CORE --> BOOKB[Booking Lifecycle]
  CORE --> REF[Refunds]
  PLATFORM --> AUTH[Identity & Access]
  PLATFORM --> NOT[Notifications]
  PLATFORM --> AUD[Audit & Observability]
EOF
cat > "$OUT/03_data_flow.mmd" <<'EOF'
flowchart LR
  C[Customer] -->|1. Search criteria| UI[Booking UI]
  UI -->|2. GET movies/shows| API[Booking API]
  API -->|3. Read catalog| CAT[(Catalog DB)]
  API -->|4. Read availability| INV[(Inventory + Redis)]
  INV -->|5. Show available seats| UI
  C -->|6. Select seats| UI
  UI -->|7. Create temporary lock| API
  API -->|8. Atomic lock with TTL| INV
  UI -->|9. Pay| API
  API -->|10. Create payment intent| PAY[Payment Gateway]
  PAY -->|11. Payment result| API
  API -->|12. Confirm booking| BOOK[(Booking DB)]
  BOOK -->|13. Publish event| MQ[Message Queue]
  MQ -->|14. Ticket notification| N[Email/SMS Service]
  N --> C
EOF
cat > "$OUT/04_class_diagram.mmd" <<'EOF'
classDiagram
  class User { +UUID userId +String name +String email +String phone +login() }
  class Movie { +UUID movieId +String title +String language +Integer durationMin +String rating }
  class Theatre { +UUID theatreId +String name +String address }
  class Screen { +UUID screenId +String name +Integer capacity }
  class Seat { +UUID seatId +String rowLabel +Integer seatNumber +SeatType type }
  class Show { +UUID showId +DateTime startsAt +DateTime endsAt +Decimal basePrice +ShowStatus status }
  class SeatLock { +UUID lockId +DateTime expiresAt +LockStatus status +acquire() +release() }
  class Booking { +UUID bookingId +String bookingCode +Decimal totalAmount +BookingStatus status +confirm() +cancel() }
  class BookingSeat { +Decimal price }
  class Payment { +UUID paymentId +Decimal amount +PaymentStatus status +String gatewayRef }
  User "1" --> "0..*" Booking : places
  Movie "1" --> "0..*" Show : scheduled_as
  Theatre "1" --> "1..*" Screen : contains
  Screen "1" --> "1..*" Seat : has
  Screen "1" --> "0..*" Show : hosts
  Show "1" --> "0..*" SeatLock : locks
  User "1" --> "0..*" SeatLock : owns
  Booking "1" --> "1..*" BookingSeat : contains
  BookingSeat "*" --> "1" Seat : reserves
  Booking "1" --> "1" Payment : paid_by
  Booking "1" --> "1" Show : for
EOF
cat > "$OUT/05_booking_sequence.mmd" <<'EOF'
sequenceDiagram
  actor Customer
  participant UI as Web/Mobile UI
  participant API as Booking API
  participant Inv as Inventory Service
  participant Pay as Payment Gateway
  participant Book as Booking Service
  participant Notify as Notification Service
  Customer->>UI: Choose movie, theatre, show
  UI->>API: Request show details
  API->>Inv: Get available seats
  Inv-->>API: Available seat map
  API-->>UI: Display seats
  Customer->>UI: Select seats and continue
  UI->>API: Request seat lock
  API->>Inv: Acquire locks with TTL
  Inv-->>API: Lock success / failure
  API-->>UI: Lock confirmation
  UI->>API: Submit payment
  API->>Pay: Create payment intent
  Pay-->>API: Payment success
  API->>Book: Create confirmed booking
  Book->>Inv: Convert locks to booked seats
  Book->>Notify: Publish ticket event
  Notify-->>Customer: Send e-ticket
  API-->>UI: Booking code and ticket
EOF
cat > "$OUT/06_database_schema.mmd" <<'EOF'
erDiagram
  USERS ||--o{ BOOKINGS : places
  MOVIES ||--o{ SHOWS : scheduled
  THEATRES ||--|{ SCREENS : contains
  SCREENS ||--|{ SEATS : has
  SCREENS ||--o{ SHOWS : hosts
  SHOWS ||--o{ SEAT_LOCKS : has
  USERS ||--o{ SEAT_LOCKS : owns
  BOOKINGS ||--|{ BOOKING_SEATS : contains
  SEATS ||--o{ BOOKING_SEATS : reserved
  SHOWS ||--o{ BOOKINGS : receives
  BOOKINGS ||--|| PAYMENTS : has
  USERS { uuid user_id PK string name string email UK string phone }
  MOVIES { uuid movie_id PK string title string language int duration_min string certification }
  THEATRES { uuid theatre_id PK string name string address }
  SCREENS { uuid screen_id PK uuid theatre_id FK string name int capacity }
  SEATS { uuid seat_id PK uuid screen_id FK string row_label int seat_number string seat_type }
  SHOWS { uuid show_id PK uuid movie_id FK uuid screen_id FK datetime starts_at decimal base_price string status }
  SEAT_LOCKS { uuid lock_id PK uuid show_id FK uuid seat_id FK uuid user_id FK datetime expires_at string status }
  BOOKINGS { uuid booking_id PK uuid user_id FK uuid show_id FK string booking_code UK decimal total_amount string status datetime booked_at }
  BOOKING_SEATS { uuid booking_id PK_FK uuid seat_id PK_FK decimal price }
  PAYMENTS { uuid payment_id PK uuid booking_id FK decimal amount string status string gateway_ref UK datetime paid_at }
EOF
for f in "$OUT"/*.mmd; do manus-render-diagram "$f" "${f%.mmd}.png" >/dev/null; done
ls -lh "$OUT"
