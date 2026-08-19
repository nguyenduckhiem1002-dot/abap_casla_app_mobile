"Value set for the free-form CHAR fields ZTB_PP_ALLOC_TXN-TRANSACTION_TYPE
"and -TRANSACTION_STATUS. Pinned here so the ledger writer, the history
"report and the mobile client cannot each invent their own spelling.
CLASS zcl_pp_txn_type DEFINITION
  PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CONSTANTS:
      "Transaction types
      initial_assign TYPE ztb_pp_alloc_txn-transaction_type VALUE 'INITIAL_ASSIGN',
      transfer       TYPE ztb_pp_alloc_txn-transaction_type VALUE 'TRANSFER',
      confirm        TYPE ztb_pp_alloc_txn-transaction_type VALUE 'CONFIRM',
      reverse        TYPE ztb_pp_alloc_txn-transaction_type VALUE 'REVERSE'.
    CONSTANTS:
      "Transaction status. Only POSTED rows count towards a worker's figures;
      "PENDING has not reached SAP yet and FAILED never will.
      posted   TYPE ztb_pp_alloc_txn-transaction_status VALUE 'POSTED',
      pending  TYPE ztb_pp_alloc_txn-transaction_status VALUE 'PENDING',
      failed   TYPE ztb_pp_alloc_txn-transaction_status VALUE 'FAILED',
      reversed TYPE ztb_pp_alloc_txn-transaction_status VALUE 'REVERSED'.
ENDCLASS.

CLASS zcl_pp_txn_type IMPLEMENTATION.
ENDCLASS.
