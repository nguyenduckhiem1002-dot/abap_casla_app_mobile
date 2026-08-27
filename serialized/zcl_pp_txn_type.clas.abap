"Bộ giá trị chuẩn cho ledger phân bổ CASLA dạng append-only.
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

    "Ledger và thay đổi nghiệp vụ được persist cùng một RAP LUW.
    "Trạng thái network/pending/transport failure thuộc hàng đợi phía mobile,
    "không được ghi như trạng thái nghiệp vụ vào immutable ledger.
    CONSTANTS posted TYPE ztb_pp_alloc_txn-transaction_status VALUE 'POSTED'.

    CONSTANTS:
      source_mobile TYPE ztb_pp_alloc_txn-source_channel VALUE 'MOBILE',
      source_fiori  TYPE ztb_pp_alloc_txn-source_channel VALUE 'FIORI',
      source_system TYPE ztb_pp_alloc_txn-source_channel VALUE 'SYSTEM'.
ENDCLASS.

CLASS zcl_pp_txn_type IMPLEMENTATION.
ENDCLASS.
