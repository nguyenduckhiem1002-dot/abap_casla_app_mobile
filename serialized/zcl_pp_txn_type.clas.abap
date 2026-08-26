"Canonical value set for the append-only CASLA allocation ledger.
CLASS zcl_pp_txn_type DEFINITION
  PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CONSTANTS:
      initial_assign TYPE ztb_pp_alloc_txn-transaction_type VALUE 'INITIAL_ASSIGN',
      transfer       TYPE ztb_pp_alloc_txn-transaction_type VALUE 'TRANSFER',
      recall         TYPE ztb_pp_alloc_txn-transaction_type VALUE 'RECALL',
      confirm        TYPE ztb_pp_alloc_txn-transaction_type VALUE 'CONFIRM',
      reverse        TYPE ztb_pp_alloc_txn-transaction_type VALUE 'REVERSE',
      correction     TYPE ztb_pp_alloc_txn-transaction_type VALUE 'CORRECTION'.

    "A ledger row exists only after the business mutation is committed in SAP.
    "Network/pending/failed transport states belong to the mobile queue, not to
    "the immutable business ledger.
    CONSTANTS posted TYPE ztb_pp_alloc_txn-transaction_status VALUE 'POSTED'.

    CONSTANTS:
      source_mobile TYPE ztb_pp_alloc_txn-source_channel VALUE 'MOBILE',
      source_fiori  TYPE ztb_pp_alloc_txn-source_channel VALUE 'FIORI',
      source_system TYPE ztb_pp_alloc_txn-source_channel VALUE 'SYSTEM'.
ENDCLASS.

CLASS zcl_pp_txn_type IMPLEMENTATION.
ENDCLASS.
