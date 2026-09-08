from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERIALIZED = ROOT / "serialized"


def object_file(name: str) -> Path:
    matches = sorted(SERIALIZED.rglob(name))
    if len(matches) != 1:
        raise SystemExit(
            f"Expected exactly one {name} below serialized/, found {len(matches)}: "
            + ", ".join(str(path.relative_to(ROOT)) for path in matches)
        )
    return matches[0]


def main() -> None:
    user_bdef = object_file("zi_mob_user.bdef.asbdef").read_text(encoding="utf-8-sig")
    if user_bdef.count("deep result [1] ZA_MOB_LoginResult") != 2:
        raise SystemExit("login/refresh phải dùng deep result ZA_MOB_LoginResult")

    pp_bdef = object_file("zr_pp_opalloc.bdef.asbdef").read_text(encoding="utf-8-sig")
    if pp_bdef.count("deep result [1] ZA_PP_HistResult") != 1:
        raise SystemExit("getWorkHistory phải dùng deep result ZA_PP_HistResult")

    md_bdef = object_file("zi_md_congdoan.bdef.asbdef").read_text(encoding="utf-8-sig")
    key_rule = "field ( mandatory : create, readonly : update ) MaCongDoan, ValidFrom;"
    if key_rule not in md_bdef:
        raise SystemExit(
            "MaCongDoan/ValidFrom phải dùng mandatory:create + readonly:update"
        )
    if "field ( mandatory ) MaCongDoan" in md_bdef:
        raise SystemExit(
            "Không được kết hợp mandatory với readonly:update cho MaCongDoan/ValidFrom"
        )

    pp_impl = object_file("zbp_r_pp_opalloc.clas.locals_imp.abap").read_text(
        encoding="utf-8-sig"
    )
    for method in (
        "initialAssign",
        "transfer",
        "recall",
        "confirm",
        "reverse",
        "correctConfirm",
    ):
        start = pp_impl.index(f"  METHOD {method}.")
        end = pp_impl.index("  ENDMETHOD.", start)
        block = pp_impl[start:end]
        if "<key>-%cid" in block:
            raise SystemExit(
                f"{method}: input của bound action không có component %cid; phải dùng %tky"
            )

    if "corrections-correction_qty" in pp_impl:
        raise SystemExit(
            "Aggregate một cột INTO @DATA(...) là scalar, không được dereference component"
        )

    history_impl = object_file("zcl_pp_work_history.clas.abap").read_text(
        encoding="utf-8-sig"
    )
    if "FOR ALL ENTRIES" in history_impl.upper():
        raise SystemExit(
            "ZCL_PP_WORK_HISTORY không được dùng FOR ALL ENTRIES; "
            "lọc ca và scope phải dùng JOIN"
        )
    if history_impl.count("SELECT FROM @scope AS scope_row") != 2:
        raise SystemExit(
            "ZCL_PP_WORK_HISTORY phải dùng đúng hai JOIN scope cho derived/candidates"
        )
    if "FIELDS DISTINCT txn~transaction_uuid" not in history_impl:
        raise SystemExit(
            "Derived scope query phải dùng FIELDS DISTINCT để loại bản ghi trùng"
        )

    for path in SERIALIZED.rglob("*.ddlx.asddlxs"):
        mde = path.read_text(encoding="utf-8-sig")
        if "@UI.facet" not in mde:
            continue
        annotate = mde.find("annotate entity ")
        if annotate < 0:
            raise SystemExit(f"{path.name}: không tìm thấy annotate entity")
        opening_brace = mde.find("{", annotate)
        if opening_brace < 0:
            raise SystemExit(f"{path.name}: không tìm thấy block annotate")
        facet_pos = mde.find("@UI.facet")
        while facet_pos >= 0:
            if facet_pos < opening_brace:
                raise SystemExit(
                    f"{path.name}: @UI.facet phải nằm trong block annotate entity ... with {{ ... }}"
                )
            facet_pos = mde.find("@UI.facet", facet_pos + 1)


if __name__ == "__main__":
    main()
