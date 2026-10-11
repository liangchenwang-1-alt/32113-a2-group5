# Source system ER diagram

The three diagrams below are **independent source systems**. There is no foreign key between databases. A person can be `C0001` in Core Banking, `P1001` in Payments, and `D1001` in Digital Service at the same time. Those ids are different keys. The warehouse team links them later with `customer_xref`, using `expected_results.csv` as the test fixture.

`CUSTOMER_ACCOUNT.customer_id` and `CUSTOMER_ACCOUNT.account_id` are logical references inside Core Banking. They are not enforced foreign keys. Payments `account_id` uses the same `A#####` format so it can be integrated later. It is not a foreign key, and `A99999` is an intentional missing account.

```mermaid
erDiagram
    CUSTOMER ||--o{ CUSTOMER_ACCOUNT : owns
    ACCOUNT ||--|| CUSTOMER_ACCOUNT : assigned_to

    PAYMENT_CUSTOMER ||--o{ TRANSACTION : makes

    DIGITAL_CUSTOMER ||--o{ ACTIVITY : performs
    DIGITAL_CUSTOMER ||--o{ SERVICE_CASE : opens
```

## Core Banking — `CBA_CORE_BANKING.CORE`

```mermaid
erDiagram
    CUSTOMER {
        VARCHAR customer_id PK
        VARCHAR first_name
        VARCHAR last_name
        DATE date_of_birth
        VARCHAR email
        VARCHAR phone
        VARCHAR customer_segment
        DATE created_date
        VARCHAR status
    }
    ACCOUNT {
        VARCHAR account_id PK
        VARCHAR account_type
        VARCHAR product_name
        DATE open_date
        NUMBER balance
        VARCHAR currency
        VARCHAR status
    }
    CUSTOMER_ACCOUNT {
        VARCHAR customer_id PK
        VARCHAR account_id PK
        VARCHAR ownership_type
        DATE relationship_from
    }
    CUSTOMER ||--o{ CUSTOMER_ACCOUNT : owns
    ACCOUNT ||--|| CUSTOMER_ACCOUNT : assigned_to
```

One account has one `PRIMARY` owner in this prototype. A customer may own more than one account.

## Payments — `CBA_PAYMENTS.PAYMENT_SRC`

```mermaid
erDiagram
    PAYMENT_CUSTOMER {
        VARCHAR payment_customer_id PK
        VARCHAR first_name
        VARCHAR last_name
        DATE date_of_birth
        VARCHAR email
        VARCHAR phone
        DATE registered_date
    }
    TRANSACTION {
        VARCHAR transaction_id PK
        VARCHAR source_transaction_ref
        VARCHAR payment_customer_id
        VARCHAR account_id
        TIMESTAMP_NTZ transaction_ts
        VARCHAR transaction_type
        NUMBER amount
        VARCHAR currency
        VARCHAR channel
        VARCHAR merchant_category
        VARCHAR status
    }
    PAYMENT_CUSTOMER ||--o{ TRANSACTION : makes
```

`source_transaction_ref` is not unique. `T000100` and `T002001` share `BREF-000100`.

## Digital and Service — `CBA_DIGITAL_SERVICE.DIGITAL_SRC`

```mermaid
erDiagram
    DIGITAL_CUSTOMER {
        VARCHAR digital_customer_id PK
        VARCHAR first_name
        VARCHAR last_name
        DATE date_of_birth
        VARCHAR email
        VARCHAR phone
        DATE signup_date
        VARCHAR preferred_channel
    }
    ACTIVITY {
        VARCHAR activity_id PK
        VARCHAR digital_customer_id
        TIMESTAMP_NTZ activity_ts
        VARCHAR channel
        VARCHAR activity_type
        VARCHAR device_type
        NUMBER session_minutes
    }
    SERVICE_CASE {
        VARCHAR case_id PK
        VARCHAR digital_customer_id
        TIMESTAMP_NTZ opened_ts
        TIMESTAMP_NTZ closed_ts
        VARCHAR channel
        VARCHAR case_type
        VARCHAR priority
        VARCHAR status
    }
    DIGITAL_CUSTOMER ||--o{ ACTIVITY : performs
    DIGITAL_CUSTOMER ||--o{ SERVICE_CASE : opens
```

`ACT000050` and `SC00020` point at `D0000`, which is not a digital customer. Those rows are rejected-record fixtures, not a modelled relationship.
